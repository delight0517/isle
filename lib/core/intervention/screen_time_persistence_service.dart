import 'dart:convert';

import 'package:flutter/services.dart';

import '../block_schedule/block_schedule_enforcement_service.dart';
import '../block_schedule/block_schedule_store.dart';
import '../block_schedule/quick_block_service.dart';
import '../platform/ios_screen_time_service.dart';
import '../platform/isle_apple_platform.dart';
import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import 'app_intervention_service.dart';
import 'app_usage_limit_store.dart';
import 'external_app_shield_store.dart';
import 'schedule_screen_time_store.dart';

/// Screen Time 앱 선택·스케줄별 선택 — 백업·Keychain·App Group 미러 + 재적용.
class ScreenTimePersistenceService {
  ScreenTimePersistenceService._();

  static const exportKey = 'screen_time_persistence';
  static const _mirrorChannel = 'com.isle.app/screen_time';
  static const _mirrorFile = 'screen_time_persistence_v1.json';
  static const _keychainKey = 'isle_screen_time_persistence_v1';

  /// Hive 박스 → JSON (export / survival backup)
  static Future<Map<String, dynamic>> exportBundle() async {
    await ExternalAppShieldStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await QuickBlockService.ensureOpen();

    final shield = <String, String>{};
    for (final k in ExternalAppShieldStore.box.keys) {
      final v = ExternalAppShieldStore.box.get(k);
      if (v != null) shield[k.toString()] = v;
    }

    final perSchedule = <String, String>{};
    for (final k in ScheduleScreenTimeStore.box.keys) {
      final v = ScheduleScreenTimeStore.box.get(k);
      if (v != null) perSchedule[k.toString()] = v;
    }

    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'external_app_shield': shield,
      'schedule_screen_time': perSchedule,
      'app_usage_limits': AppUsageLimitStore.box.get('rules_json'),
      'quick_block_sessions': QuickBlockService.loadSessions()
          .map((s) => s.toJson())
          .toList(),
    };
  }

  static Future<void> syncMirror() async {
    if (!IsleApplePlatform.isScreenTimeHost) return;
    try {
      // 차단 스케줄·마스터 플래그도 Keychain 미러에 포함 — 재설치(앱 데이터 초기화) 후에도
      // Keychain은 살아남으므로 스케줄이 사라지지 않는다. (파일 백업은 iOS 샌드박스라 삭제 시 소실)
      await BlockScheduleStore.ensureOpen();
      final bundle = await exportBundle();
      bundle['block_schedules'] =
          BlockScheduleStore.loadAll().map((e) => e.toJson()).toList();
      bundle['schedule_master_enabled'] =
          IsleUserDefaults.youtubeScheduleLockEnabled;
      final json = jsonEncode(bundle);
      await const MethodChannel(_mirrorChannel).invokeMethod<void>(
        'writePersistenceMirror',
        {'json': json},
      );
      await const MethodChannel(_mirrorChannel).invokeMethod<void>(
        'savePersistenceKeychain',
        {'json': json},
      );
    } catch (e, st) {
      IsleAppLogService.log(
        'ScreenTimePersistence mirror: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
    }
  }

  /// Keychain / App Group → Hive (재설치·빈 Hive 시)
  static Future<bool> restoreFromNativeMirrorIfNeeded() async {
    if (!IsleApplePlatform.isScreenTimeHost) return false;

    await ExternalAppShieldStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await BlockScheduleStore.ensureOpen();

    final hiveEmpty = !ExternalAppShieldStore.hasSelection &&
        ScheduleScreenTimeStore.box.isEmpty &&
        BlockScheduleStore.loadAll().isEmpty;

    if (!hiveEmpty) return false;

    String? raw;
    try {
      raw = await const MethodChannel(_mirrorChannel).invokeMethod<String>(
        'loadPersistenceKeychain',
      );
      raw ??= await const MethodChannel(_mirrorChannel).invokeMethod<String>(
        'loadPersistenceMirror',
      );
    } catch (e, st) {
      IsleAppLogService.log('ScreenTimePersistence load mirror: $e', level: IsleLogLevel.warn, stack: st);
    }

    if (raw == null || raw.trim().isEmpty) return false;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      await importBundle(map);
      IsleAppLogService.log('ScreenTimePersistence restored from native mirror');
      return true;
    } catch (e, st) {
      IsleAppLogService.log('ScreenTimePersistence parse mirror: $e', level: IsleLogLevel.error, stack: st);
      return false;
    }
  }

  static Future<void> importBundle(Map<String, dynamic> bundle) async {
    await ExternalAppShieldStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await QuickBlockService.ensureOpen();

    final shield = bundle['external_app_shield'];
    if (shield is Map) {
      for (final e in shield.entries) {
        await ExternalAppShieldStore.box.put(e.key.toString(), e.value.toString());
      }
    }

    final perSchedule = bundle['schedule_screen_time'];
    if (perSchedule is Map) {
      for (final e in perSchedule.entries) {
        await ScheduleScreenTimeStore.box.put(e.key.toString(), e.value.toString());
      }
    }

    final limits = bundle['app_usage_limits'];
    if (limits is String && limits.isNotEmpty) {
      await AppUsageLimitStore.box.put('rules_json', limits);
    }

    final qb = bundle['quick_block_sessions'];
    if (qb is List && qb.isNotEmpty) {
      await QuickBlockService.restoreSessionsFromJson(qb);
    }
  }

  /// survival restore / mirror restore 직후 — 이미 승인됐으면 쉴드만 다시 적용.
  ///
  /// 업데이트마다 FamilyControls 인가가 초기화되는 문제 대응:
  ///  - 이미 `.approved` → 즉시 쉴드 재적용 (다이얼로그 없음)
  ///  - `.notDetermined` → 자동 재요청 (이미 승인됐으면 내부에서 즉시 반환)
  ///  - 실패 시 → 기존 배너 방식 폴백
  static Future<void> reapplyIfAuthorized({bool force = false}) async {
    if (!IsleApplePlatform.isScreenTimeHost) return;
    if (!await IosScreenTimeService.isAvailable()) return;

    final hasData = ExternalAppShieldStore.hasSelection ||
        ScheduleScreenTimeStore.box.isNotEmpty;
    if (!hasData) return;

    if (!await IosScreenTimeService.isAuthorized()) {
      // 이미 승인됐으면 requestAuthorization은 즉시 반환(다이얼로그 없음).
      // notDetermined이면 OS 다이얼로그를 자동으로 띄운다.
      IsleAppLogService.log('Screen Time: not authorized — attempting auto re-auth');
      final result = await IosScreenTimeService.requestAuthorizationDetailed();
      if (!result.ok) {
        await IsleUserDefaults.setPendingScreenTimeReapply(true);
        IsleAppLogService.log(
          'Screen Time: re-auth failed (${result.code}) — showing banner',
        );
        return;
      }
      IsleAppLogService.log('Screen Time: re-auth succeeded automatically');
    }

    await IsleUserDefaults.setPendingScreenTimeReapply(false);
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: force);
    if (ExternalAppShieldStore.hasSelection &&
        !BlockScheduleStore.masterEnabled) {
      await AppInterventionService.applySavedAppShield();
    }
    IsleAppLogService.log('Screen Time: shields re-applied from saved picks');
  }

  /// `main()` — survival restore 이후
  static Future<void> bootstrapAfterDataLoad() async {
    await restoreFromNativeMirrorIfNeeded();
    await reapplyIfAuthorized(force: true);
  }

  /// 사용자가 Screen Time 승인 직후 (설정 화면 등)
  static Future<void> onAuthorizationGranted() async {
    await syncMirror();
    await reapplyIfAuthorized(force: true);
  }
}
