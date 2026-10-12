import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../island/island_snapshot_store.dart';
import '../island/local_shelf_store.dart';
import '../focus/kakao_shorts_addiction_store.dart';
import '../intervention/external_app_shield_store.dart';
import '../intervention/schedule_screen_time_store.dart';
import '../intervention/screen_time_persistence_service.dart';
import '../intervention/website_block_store.dart';
import '../youtube/blocked_url_store.dart';
import '../youtube/blocked_channel_store.dart';
import '../youtube/content_filter_store.dart';
import '../block_schedule/block_schedule_store.dart';
import '../library/personal_library_store.dart';
import 'setup_journey_service.dart';
import '../ai/ai_config_store.dart';
import 'isle_backup_codec.dart';
import 'isle_app_log_service.dart';
import 'isle_data_export_service.dart';
import 'isle_keychain_survival_store.dart';
import 'isle_install_identity_service.dart';
import 'isle_user_defaults.dart';

/// 앱 삭제 후 재설치해도 차단·스케줄·라이브러리가 돌아오도록
/// 샌드박스 밖 `~/Documents/Isle Backup/current.json` 에 미러링 (Mac 기본).
class IsleSurvivalBackupService {
  IsleSurvivalBackupService._();

  static const snapshotVersion = 10;
  static const _folderPrefKey = 'isle_survival_backup_folder';
  static const _lastSyncKey = 'isle_survival_last_sync';
  static const _currentFileName = 'current.json';
  static const _tmpFileName = 'current.json.tmp';

  static bool _safeToSync = false;
  static bool _snapshotsEnabled = true;
  static Timer? _debounce;
  static DateTime? lastSyncAt;

  static Box<String> get _prefs => Hive.box<String>('isle_cache');

  /// `main()` — 모든 Hive 박스 연 뒤, `runApp` 전
  static Future<void> bootstrapOnLaunch() async {
    await LocalShelfStore.ensureOpen();
    await ensureBootstrapped();
    final fresh = await localLooksFresh();
    var restored = false;

    if (fresh && await IsleKeychainSurvivalStore.hasSnapshot()) {
      IsleAppLogService.log('Survival backup: fresh sandbox → keychain restore');
      restored = await _restoreFromKeychain();
      if (restored) {
        await IsleUserDefaults.setPendingRestoreNotice('keychain');
      }
    }

    if (!restored) {
      final snap = await _currentFile();
      if (fresh &&
          snap != null &&
          await _snapshotHasMeaningfulData(snap)) {
        IsleAppLogService.log('Survival backup: fresh install → restore from ${snap.path}');
        await restoreNow(confirm: false);
        await IsleUserDefaults.setPendingRestoreNotice('folder');
        restored = true;
      } else if (fresh) {
        IsleAppLogService.log(
          'Survival backup: local looks fresh — skip folder restore '
          '(no meaningful current.json)',
        );
      }
    } else if (fresh && await IsleInstallIdentityService.hadPriorInstallOnDevice()) {
      final prior = await IsleInstallIdentityService.priorBuildOnDevice();
      IsleAppLogService.log(
        'Survival backup: reinstall detected (prior build ${prior ?? "?"})',
      );
    }

    _safeToSync = true;
    if (!fresh || !restored) {
      await syncNow();
    } else {
      await syncNow();
    }
  }

  static Future<void> ensureBootstrapped() async {
    await _ensureAndroidDefaultFolderIfNeeded();
    final dir = await writableBackupDirectory();
    _snapshotsEnabled = await _probeSnapshotsWritable(dir.path);
    final raw = _prefs.get(_lastSyncKey);
    if (raw != null) {
      lastSyncAt = DateTime.tryParse(raw);
    }
  }

  /// iCloud File Provider·일부 공유 볼륨 — 하위 폴더 생성 불가
  static bool isRestrictedBackupPath(String path) {
    final p = path.toLowerCase();
    return p.contains('file provider storage') ||
        p.contains('/livefiles/') ||
        p.contains('.nosync/') ||
        p.contains('/appgroup/');
  }

  static Future<String?> validateWritableBackupFolder(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '폴더가 비어 있어요.';
    final dir = Directory(trimmed);
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final probe = File('${dir.path}/.isle_backup_write_test');
      await probe.writeAsString('ok', flush: true);
      if (!await probe.exists()) {
        return '이 폴더에는 파일을 쓸 수 없어요.';
      }
      await probe.delete();
      return null;
    } on PathAccessException catch (e) {
      return _folderPickErrorMessage(trimmed, e);
    } on FileSystemException catch (e) {
      return _folderPickErrorMessage(trimmed, e);
    } catch (e) {
      return '백업 폴더를 사용할 수 없어요: $e';
    }
  }

  static String _folderPickErrorMessage(String path, Object e) {
    if (isRestrictedBackupPath(path) || path.toLowerCase().contains('icloud')) {
      return 'iCloud에서는 「파일」앱 → iCloud Drive → Isle Backup 폴더를 '
          '직접 만든 뒤 그 폴더를 선택해 주세요. (다른 앱 백업 폴더는 쓸 수 없어요)';
    }
    return '이 폴더에 쓸 수 없어요: $e';
  }

  static Future<bool> _probeSnapshotsWritable(String parentPath) async {
    if (isRestrictedBackupPath(parentPath)) return false;
    final snapDir = Directory('$parentPath/snapshots');
    try {
      if (!await snapDir.exists()) {
        await snapDir.create(recursive: true);
      }
      final probe = File('${snapDir.path}/.isle_snap_probe');
      await probe.writeAsString('1', flush: true);
      await probe.delete();
      return true;
    } catch (e) {
      IsleAppLogService.log(
        'Survival snapshots off for $parentPath: $e',
        level: IsleLogLevel.info,
      );
      return false;
    }
  }

  static Future<Directory> defaultBackupDirectory() async {
    if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory('$home/Documents/Isle Backup');
      }
    }
    if (Platform.isWindows) {
      final profile = Platform.environment['USERPROFILE'];
      if (profile != null && profile.isNotEmpty) {
        return Directory('$profile\\Documents\\Isle Backup');
      }
    }
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        return Directory('${ext.path}/Isle Backup');
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/Isle Backup');
  }

  static Future<Directory> backupDirectory() async {
    final custom = _prefs.get(_folderPrefKey);
    if (custom != null && custom.trim().isNotEmpty) {
      return Directory(custom.trim());
    }
    return defaultBackupDirectory();
  }

  /// 실제 sync·복원에 쓰는 경로 — File Provider/iCloud 등 쓰기 불가면 Documents fallback
  static Future<Directory> writableBackupDirectory() async {
    final custom = _prefs.get(_folderPrefKey)?.trim();
    if (custom != null && custom.isNotEmpty) {
      if (!isRestrictedBackupPath(custom)) {
        final err = await validateWritableBackupFolder(custom);
        if (err == null) return Directory(custom);
        IsleAppLogService.log(
          'Survival backup: custom folder unusable → Documents fallback ($err)',
          level: IsleLogLevel.warn,
        );
      } else {
        IsleAppLogService.log(
          'Survival backup: File Provider path → Documents fallback',
          level: IsleLogLevel.info,
        );
      }
    }
    final def = await defaultBackupDirectory();
    try {
      if (!await def.exists()) await def.create(recursive: true);
    } catch (e) {
      IsleAppLogService.log(
        'Survival backup default dir create failed: $e',
        level: IsleLogLevel.error,
      );
    }
    return def;
  }

  static bool hasUserChosenBackupFolder() {
    final custom = _prefs.get(_folderPrefKey)?.trim();
    return custom != null && custom.isNotEmpty;
  }

  /// iPhone — 앱 삭제 시 샌드박스 백업은 사라짐 → iCloud 등 외부 폴더 권장
  static bool needsIcloudFolderPrompt() {
    if (!Platform.isIOS) return false;
    return !hasUserChosenBackupFolder();
  }

  static bool isLikelyCloudOrExternalPath(String path) {
    final p = path.toLowerCase();
    return p.contains('icloud') ||
        p.contains('mobile documents') ||
        p.contains('/documents/isle backup');
  }

  static Future<void> setBackupFolder(String path) async {
    final trimmed = path.trim();
    final err = await validateWritableBackupFolder(trimmed);
    if (err != null) {
      throw StateError(err);
    }
    final prev = _prefs.get(_folderPrefKey);
    await _prefs.put(_folderPrefKey, trimmed);
    try {
      await ensureBootstrapped();
      await syncNow();
    } catch (e) {
      if (prev != null && prev.trim().isNotEmpty) {
        await _prefs.put(_folderPrefKey, prev);
      } else {
        await _prefs.delete(_folderPrefKey);
      }
      rethrow;
    }
  }

  static Future<String?> pickBackupFolder() async {
    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Isle 백업 폴더 선택 (iCloud Drive → Isle Backup 권장)',
    );
    if (picked == null || picked.isEmpty) return null;
    try {
      await setBackupFolder(picked);
    } on StateError catch (e) {
      throw StateError(e.message);
    }
    await SetupJourneyService.markStepDone('icloud_backup');
    return picked;
  }

  static Future<void> openBackupFolderInFinder() async {
    final dir = await backupDirectory();
    await ensureBootstrapped();
    if (Platform.isMacOS) {
      await Process.run('open', [dir.path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [dir.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dir.path]);
    }
  }

  static String get platformSurvivalHint {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return 'Mac/PC: 기본 백업은 Documents/Isle Backup 에 있어 앱을 삭제해도 유지됩니다.';
    }
    if (Platform.isAndroid) {
      return 'Android: 기본은 외부 저장소/Android/data/…/Isle Backup (앱 업데이트 후에도 유지). '
          '앱 삭제 후에도 남기려면 「폴더 변경」으로 Downloads·Google Drive 등을 고르세요. '
          '시스템 자동 백업(설정)도 켜 두면 업데이트·재설치에 도움이 됩니다.';
    }
    return 'iPhone: 앱 삭제·재설치 시 샌드박스는 지워집니다. '
        '「파일」→ iCloud Drive → Isle Backup 폴더를 만든 뒤 '
        '설정 → 데이터 백업 → 「폴더 변경」으로 그 폴더를 지정하세요. '
        'Keychain 미러도 자동 복원을 시도합니다.';
  }

  /// true = Hive가 비어 있음(재설치·초기화). false = 기존 사용자 → 덮어쓰기·checkpoint replace 금지.
  static Future<bool> localLooksFresh() async {
    await LocalShelfStore.ensureOpen();
    for (final key in LocalShelfStore.box.keys) {
      final raw = LocalShelfStore.box.get(key);
      if (raw != null && raw.length > 4) return false;
    }
    if (BlockedChannelStore.loadAll().isNotEmpty) return false;
    if (ContentFilterStore.loadKeywords().isNotEmpty) return false;
    if (ContentFilterStore.loadVideos().isNotEmpty) return false;
    if (BlockedUrlStore.loadAll().isNotEmpty) return false;
    if (BlockScheduleStore.loadAll().isNotEmpty) return false;
    if (PersonalLibraryStore.loadEntries().isNotEmpty) return false;
    if (PersonalLibraryStore.loadSources().isNotEmpty) return false;
    if (WebsiteBlockStore.loadDomains().isNotEmpty) return false;
    if (ExternalAppShieldStore.isOpen && ExternalAppShieldStore.hasSelection) {
      return false;
    }
    await KakaoShortsAddictionStore.ensureOpen();
    if (KakaoShortsAddictionStore.loadSessions().isNotEmpty) return false;
    await ScheduleScreenTimeStore.ensureOpen();
    for (final key in ScheduleScreenTimeStore.box.keys) {
      final raw = ScheduleScreenTimeStore.box.get(key);
      if (raw != null && raw.trim().length > 2) return false;
    }
    await IslandSnapshotStore.ensureOpen();
    if (IslandSnapshotStore.box.keys.isNotEmpty) return false;
    await AiConfigStore.ensureOpen();
    for (final key in AiConfigStore.box.keys) {
      if (key.toString() == 'api_key') continue;
      final v = AiConfigStore.box.get(key);
      if (v != null && v.trim().isNotEmpty) return false;
    }
    if (await _documentsCheckpointHasMeaningfulData()) return false;
    if (_cacheHasMeaningfulUserState()) return false;
    return true;
  }

  /// JSON 스냅샷(export / survival / checkpoint)에 실사용 데이터가 있는지.
  static bool snapshotMapHasMeaningfulData(Map<String, dynamic> m) {
    bool hasList(String key) {
      final v = m[key];
      return v is List && v.isNotEmpty;
    }

    final userPrefs = m['user_prefs'];
    if (userPrefs is Map && userPrefs.isNotEmpty) return true;
    final ai = m['ai_config'];
    if (ai is Map && ai.isNotEmpty) return true;
    final shelves = m['local_shelves'];
    if (shelves is List && shelves.isNotEmpty) return true;
    final islandBox = m['island_snapshot_box'];
    if (islandBox is Map && islandBox.isNotEmpty) return true;

    return hasList('blocked_channels') ||
        hasList('blocked_keywords') ||
        hasList('blocked_videos') ||
        hasList('block_schedules') ||
        hasList('library_entries') ||
        hasList('interest_pipeline') ||
        hasList('feed_boost_channels') ||
        hasList('brunch_blocked_authors') ||
        (m['isle_social'] is Map) ||
        hasList('instagram_following') ||
        hasList('local_shelves') ||
        (m[ScreenTimePersistenceService.exportKey] is Map &&
            (m[ScreenTimePersistenceService.exportKey] as Map).isNotEmpty);
  }

  static Future<bool> _documentsCheckpointHasMeaningfulData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/isle_state_checkpoint.b64');
      if (!await file.exists()) return false;
      final raw = await file.readAsString();
      if (raw.trim().length < 32) return false;
      final decoded = IsleBackupCodec.decode(raw);
      return snapshotMapHasMeaningfulData(decoded);
    } catch (_) {
      return false;
    }
  }

  static bool _cacheHasMeaningfulUserState() {
    if (_prefs.get(_lastSyncKey)?.trim().isNotEmpty == true) return true;
    if (_prefs.get(_folderPrefKey)?.trim().isNotEmpty == true) return true;
    var prefKeys = 0;
    for (final key in _prefs.keys) {
      final k = key.toString();
      if (k.startsWith('isle_pref_')) prefKeys++;
    }
    // applyCommanderDefaults 이후 2회째 실행부터는 설정 키가 쌓임
    return prefKeys >= 8;
  }

  static Future<File?> _currentFile() async {
    final dir = await writableBackupDirectory();
    final f = File('${dir.path}/$_currentFileName');
    if (await f.exists()) return f;
    return null;
  }

  static Future<Directory> _snapshotsDir() async {
    final dir = await writableBackupDirectory();
    return Directory('${dir.path}/snapshots');
  }

  static void onDataChanged() {
    if (!_safeToSync) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(syncNow());
    });
  }

  static Future<void> scheduleSync() => syncNow();

  static Future<Map<String, dynamic>> buildSnapshotMap() async {
    final base = await IsleDataExportService.buildExportPayload();
    return {
      ...base,
      'snapshot_version': snapshotVersion,
      'backup_app': 'isle',
      'user_prefs': _exportUserPrefs(),
      'ai_config': _exportAiConfig(),
      'island_snapshot_box': _exportIslandSnapshotBox(),
      'local_shelves': _exportLocalShelves(),
    };
  }

  static List<Map<String, dynamic>> _exportLocalShelves() {
    final out = <Map<String, dynamic>>[];
    for (final key in LocalShelfStore.box.keys) {
      final raw = LocalShelfStore.box.get(key);
      if (raw == null) continue;
      try {
        final list = jsonDecode(raw) as List;
        for (final e in list) {
          if (e is Map) out.add(Map<String, dynamic>.from(e));
        }
      } catch (_) {}
    }
    return out;
  }

  static Map<String, String> _exportUserPrefs() {
    final out = <String, String>{};
    for (final key in _prefs.keys) {
      final k = key.toString();
      if (k.startsWith('isle_pref_')) {
        final v = _prefs.get(key);
        if (v != null) out[k] = v;
      }
    }
    return out;
  }

  static Map<String, String> _exportAiConfig() {
    final out = <String, String>{};
    for (final key in AiConfigStore.box.keys) {
      final k = key.toString();
      if (k == 'api_key') continue;
      final v = AiConfigStore.box.get(key);
      if (v != null) out[k] = v;
    }
    return out;
  }

  static Map<String, String> _exportIslandSnapshotBox() {
    final out = <String, String>{};
    for (final key in IslandSnapshotStore.box.keys) {
      final v = IslandSnapshotStore.box.get(key);
      if (v != null) out[key.toString()] = v;
    }
    return out;
  }

  static Future<bool> _snapshotHasMeaningfulData(File file) async {
    try {
      final m = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return snapshotMapHasMeaningfulData(m);
    } catch (_) {
      return false;
    }
  }

  static Future<void> syncNow() async {
    if (!_safeToSync) return;
    final existing = await _currentFile();
    if (await localLooksFresh() &&
        existing != null &&
        await _snapshotHasMeaningfulData(existing)) {
      return;
    }
    try {
      await ensureBootstrapped();
      final map = await buildSnapshotMap();
      final dir = await writableBackupDirectory();
      final current = File('${dir.path}/$_currentFileName');
      final tmp = File('${dir.path}/$_tmpFileName');
      final encoded = const JsonEncoder.withIndent('  ').convert(map);
      await tmp.writeAsString(encoded, flush: true);
      if (!await tmp.exists()) return;
      if (await current.exists()) {
        try {
          await current.delete();
        } on FileSystemException {
          // 동시 sync — 무시
        }
      }
      try {
        await tmp.rename(current.path);
      } on FileSystemException {
        if (await tmp.exists()) {
          await tmp.copy(current.path);
          try {
            await tmp.delete();
          } on FileSystemException {
            // best-effort
          }
        }
      }
      lastSyncAt = DateTime.now();
      await _prefs.put(_lastSyncKey, lastSyncAt!.toIso8601String());
      await _writeDailySnapshotIfNeeded(encoded);
      await IsleKeychainSurvivalStore.saveSnapshotJson(encoded);
      IsleAppLogService.log('Survival backup synced → ${current.path}');
    } catch (e, st) {
      IsleAppLogService.log('Survival backup sync failed: $e', level: IsleLogLevel.error);
      IsleAppLogService.log(st.toString(), level: IsleLogLevel.debug);
    }
  }

  static Future<void> _writeDailySnapshotIfNeeded(String encoded) async {
    if (!_snapshotsEnabled) return;
    try {
      final snapDir = await _snapshotsDir();
      if (!await snapDir.exists()) {
        await snapDir.create(recursive: true);
      }
      final day = DateTime.now();
      final name =
          'snapshot_${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}.json';
      final file = File('${snapDir.path}/$name');
      if (!await file.exists()) {
        await file.writeAsString(encoded);
      }
    } catch (e) {
      _snapshotsEnabled = false;
      IsleAppLogService.log(
        'Survival daily snapshot skipped: $e',
        level: IsleLogLevel.info,
      );
    }
  }

  static Future<bool> _restoreFromKeychain() async {
    final raw = await IsleKeychainSurvivalStore.loadSnapshotJson();
    if (raw == null) return false;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (!snapshotMapHasMeaningfulData(decoded)) return false;
      final wasSafe = _safeToSync;
      _safeToSync = false;
      try {
        final count = await importSnapshotString(raw);
        IsleAppLogService.log('Survival keychain restore: ~$count items');
        return count > 0;
      } finally {
        _safeToSync = wasSafe;
      }
    } catch (e, st) {
      IsleAppLogService.log(
        'Survival keychain restore failed: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
      return false;
    }
  }

  static Future<int> restoreNow({bool confirm = true}) async {
    final file = await _currentFile();
    if (file == null) {
      throw StateError('current.json 이 없습니다.');
    }
    final wasSafe = _safeToSync;
    _safeToSync = false;
    try {
      final raw = await file.readAsString();
      final count = await importSnapshotString(raw);
      IsleAppLogService.log('Survival restore: ~$count items from ${file.path}');
      return count;
    } finally {
      _safeToSync = wasSafe;
      if (_safeToSync) {
        await syncNow();
      }
    }
  }

  static Future<int> importSnapshotString(String raw) async {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    var count = await IsleDataExportService.importFromJsonString(raw);

    final prefs = decoded['user_prefs'];
    if (prefs is Map) {
      for (final e in prefs.entries) {
        await _prefs.put(e.key.toString(), e.value.toString());
        count++;
      }
    }

    final ai = decoded['ai_config'];
    if (ai is Map) {
      for (final e in ai.entries) {
        final k = e.key.toString();
        final v = e.value.toString();
        if (k == 'api_key') {
          await AiConfigStore.setApiKey(v);
          count++;
          continue;
        }
        await AiConfigStore.box.put(k, v);
        count++;
      }
    }

    final islandBox = decoded['island_snapshot_box'];
    if (islandBox is Map) {
      for (final e in islandBox.entries) {
        await IslandSnapshotStore.box.put(e.key.toString(), e.value.toString());
        count++;
      }
    }

    final localShelves = decoded['local_shelves'];
    if (localShelves is List && localShelves.isNotEmpty) {
      await LocalShelfStore.ensureOpen();
      final byUser = <String, List<Map<String, dynamic>>>{};
      for (final item in localShelves) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final uid = m['user_id'] as String? ?? 'local';
        byUser.putIfAbsent(uid, () => []).add(m);
      }
      for (final e in byUser.entries) {
        await LocalShelfStore.box.put(
          'uid_${e.key}',
          jsonEncode(e.value),
        );
        count += e.value.length;
      }
    }

    await ScreenTimePersistenceService.syncMirror();
    return count;
  }

  static Future<String> backupFolderLabel() async {
    final dir = await backupDirectory();
    return dir.path;
  }

  static const _androidDefaultFolderKey = 'isle_survival_android_default_v1';

  /// Android: 외부 앱 폴더를 기본 백업 위치로 한 번만 고정 (업데이트·로그인 후에도 동일 경로)
  static Future<void> _ensureAndroidDefaultFolderIfNeeded() async {
    if (!Platform.isAndroid) return;
    if (_prefs.get(_folderPrefKey)?.trim().isNotEmpty == true) return;
    if (_prefs.get(_androidDefaultFolderKey) == '1') return;
    final ext = await getExternalStorageDirectory();
    if (ext == null) return;
    final dir = Directory('${ext.path}/Isle Backup');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _prefs.put(_folderPrefKey, dir.path);
    await _prefs.put(_androidDefaultFolderKey, '1');
    IsleAppLogService.log('Android survival backup folder → ${dir.path}');
  }
}
