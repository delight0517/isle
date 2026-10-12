import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'isle_app_log_service.dart';
import 'isle_backup_codec.dart';
import 'isle_backup_service.dart';
import 'isle_survival_backup_service.dart';
import 'isle_user_defaults.dart';

/// 25초 주기 + 앱 종료 시 스냅샷 (강제 종료 대비)
class IsleCheckpointService {
  IsleCheckpointService._();

  static const _fileName = 'isle_state_checkpoint.b64';
  static const _tmpName = 'isle_state_checkpoint.tmp';

  static Timer? _periodic;

  static void startPeriodicCheckpoint() {
    _periodic?.cancel();
    _periodic = Timer.periodic(const Duration(seconds: 25), (_) {
      unawaited(snapshot());
    });
  }

  static void stopPeriodicCheckpoint() {
    _periodic?.cancel();
    _periodic = null;
  }

  static Future<File> _checkpointFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> snapshot() async {
    try {
      final map = await IsleSurvivalBackupService.buildSnapshotMap();
      final encoded = IsleBackupCodec.encode(map);
      final dir = await getApplicationDocumentsDirectory();
      final tmp = File('${dir.path}/$_tmpName');
      await tmp.writeAsString(encoded, flush: true);
      if (!await tmp.exists()) return;
      final target = await _checkpointFile();
      if (await target.exists()) {
        try {
          await target.delete();
        } catch (_) {
          // race·이미 삭제됨 — 무시
        }
      }
      try {
        await tmp.rename(target.path);
      } on FileSystemException {
        if (await tmp.exists()) {
          await tmp.copy(target.path);
          try {
            await tmp.delete();
          } catch (_) {
            // best-effort
          }
        }
      }
    } catch (e, st) {
      final low = e.toString().toLowerCase();
      if (low.contains('pathnotfoundexception')) {
        IsleAppLogService.log('Checkpoint noop: $e', level: IsleLogLevel.debug);
      } else {
        IsleAppLogService.log('Checkpoint failed: $e', level: IsleLogLevel.warn, stack: st);
      }
    }
  }

  static Future<bool> restoreFromCheckpointIfLocalEmpty() async {
    if (!await IsleSurvivalBackupService.localLooksFresh()) {
      IsleAppLogService.log(
        'Checkpoint restore skipped: local data present (not fresh)',
      );
      return false;
    }
    try {
      final file = await _checkpointFile();
      if (!await file.exists()) return false;
      final raw = await file.readAsString();
      final Map<String, dynamic> decoded;
      try {
        decoded = IsleBackupCodec.decode(raw);
      } catch (e) {
        IsleAppLogService.log(
          'Checkpoint restore skipped: invalid payload ($e)',
          level: IsleLogLevel.warn,
        );
        return false;
      }
      if (!IsleSurvivalBackupService.snapshotMapHasMeaningfulData(decoded)) {
        IsleAppLogService.log(
          'Checkpoint restore skipped: checkpoint has no meaningful data',
        );
        return false;
      }
      final count = await IsleBackupService.restore(raw, IsleRestoreMode.replaceAll);
      IsleAppLogService.log('Checkpoint restore: ~$count items');
      if (count > 0) await IsleUserDefaults.setPendingRestoreNotice('checkpoint');
      return count > 0;
    } catch (e) {
      IsleAppLogService.log('Checkpoint restore skipped: $e', level: IsleLogLevel.warn);
      return false;
    }
  }

  /// Documents checkpoint exists (used to avoid false "fresh" wipes).
  static Future<bool> hasCheckpointPayload() async {
    try {
      final file = await _checkpointFile();
      if (!await file.exists()) return false;
      final raw = await file.readAsString();
      if (raw.trim().length < 32) return false;
      final decoded = IsleBackupCodec.decode(raw);
      return IsleSurvivalBackupService.snapshotMapHasMeaningfulData(decoded);
    } catch (_) {
      return false;
    }
  }
}
