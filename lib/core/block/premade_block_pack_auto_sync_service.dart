import 'dart:async';

import '../safety/adult_protection_service.dart';
import '../services/isle_app_log_service.dart';
import 'premade_block_pack_registry.dart';
import 'premade_block_pack_service.dart';

/// 연결된 4VPN 프리셋 — manifest 등록 팩 전부 자동 동기화
class PremadeBlockPackAutoSyncService {
  PremadeBlockPackAutoSyncService._();

  static bool _running = false;

  static Future<void> syncAllApplied({bool silent = true}) async {
    if (_running) return;
    _running = true;
    try {
      await PremadeBlockPackRegistry.ensureLoaded();

      if (AdultProtectionService.isFull &&
          PremadeBlockPackService.isPackApplied(PremadeBlockPackService.adultCombinedPackId)) {
        await _syncOne(PremadeBlockPackService.adultCombinedPackId, silent: silent);
      }

      for (final def in PremadeBlockPackRegistry.toggleDefinitions()) {
        if (!PremadeBlockPackService.isPackApplied(def.packId)) continue;
        await _syncOne(def.packId, silent: silent);
      }
    } finally {
      _running = false;
    }
  }

  static Future<void> _syncOne(String packId, {required bool silent}) async {
    try {
      final result = await PremadeBlockPackService.applyPack(
        packId,
        silent: silent,
      );
      if (result.totalAdded > 0) {
        IsleAppLogService.log(
          'Premade auto-sync $packId: +${result.totalAdded}',
        );
      }
    } catch (e) {
      IsleAppLogService.log(
        'Premade auto-sync failed $packId: $e',
        level: IsleLogLevel.warn,
      );
    }
  }
}
