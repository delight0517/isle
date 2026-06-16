import 'dart:convert';

import 'isle_app_log_service.dart';
import 'isle_backup_codec.dart';
import 'isle_data_export_service.dart';
import 'isle_survival_backup_service.dart';

enum IsleRestoreMode { replaceAll, merge }

/// Base64 백업 코드 —보내기·Replace All·Merge
class IsleBackupService {
  IsleBackupService._();

  static Future<String> exportCode() async {
    final map = await IsleSurvivalBackupService.buildSnapshotMap();
    final code = IsleBackupCodec.encode(map);
    IsleAppLogService.log('Backup code exported (${code.length} chars)');
    return code;
  }

  static Future<int> restore(String raw, IsleRestoreMode mode) async {
    try {
      final pack = IsleBackupCodec.decode(raw);
      final count = switch (mode) {
        IsleRestoreMode.replaceAll => await _replaceAll(pack),
        IsleRestoreMode.merge => await IsleSurvivalBackupService.importSnapshotString(
            jsonEncode(pack),
          ),
      };
      await IsleSurvivalBackupService.syncNow();
      IsleAppLogService.log('Restore ${mode.name} ok (~$count items)');
      return count;
    } catch (e, st) {
      IsleAppLogService.log('Restore ${mode.name} failed: $e', level: IsleLogLevel.error, stack: st);
      rethrow;
    }
  }

  static Future<int> _replaceAll(Map<String, dynamic> pack) async {
    await IsleDataExportService.clearAllUserData();
    return IsleSurvivalBackupService.importSnapshotString(jsonEncode(pack));
  }
}
