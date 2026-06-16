import 'dart:io' show Platform;

import '../block_schedule/block_schedule_enforcement_service.dart';
import '../block_schedule/schedule_active_service.dart';
import '../platform/ios_screen_time_service.dart';
import '../platform/isle_apple_platform.dart';
import '../services/isle_app_log_service.dart';
import 'app_intervention_service.dart';
import 'external_app_shield_store.dart';
import 'schedule_screen_time_store.dart';

/// 스케줄별 FamilyActivityPicker + App Group 동기화.
class ScheduleScreenTimeService {
  ScheduleScreenTimeService._();

  static Future<bool> pickForSchedule(
    String scheduleId, {
    bool additiveOnly = false,
  }) async {
    if (Platform.isAndroid) {
      await ScheduleScreenTimeStore.ensureOpen();
      if (!await AppInterventionService.ensureAuthorized()) return false;

      final existing = ScheduleScreenTimeStore.encodedFor(scheduleId) ??
          (additiveOnly ? ExternalAppShieldStore.encodedSelection : null);

      final pick = await AppInterventionService.pickApps(existingEncoded: existing);
      if (pick == null) return false;

      await ScheduleScreenTimeStore.savePick(
        scheduleId: scheduleId,
        encoded: pick.encoded,
        applicationCount: pick.applicationCount,
        categoryCount: pick.categoryCount,
      );
      IsleAppLogService.log(
        'schedule Android pick $scheduleId apps=${pick.applicationCount}',
      );
      await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
      return true;
    }

    if (!IsleApplePlatform.isScreenTimeHost) return false;
    await ScheduleScreenTimeStore.ensureOpen();
    if (!await IosScreenTimeService.isAuthorized()) {
      final auth = await IosScreenTimeService.requestAuthorizationDetailed();
      if (!auth.ok) return false;
    }

    final existing = ScheduleScreenTimeStore.encodedFor(scheduleId) ??
        (additiveOnly ? ExternalAppShieldStore.encodedSelection : null);

    final pick = await IosScreenTimeService.pickFamilyActivitySelection(
      existingEncoded: existing,
      additiveOnly: additiveOnly,
    );
    if (pick == null) return false;

    await ScheduleScreenTimeStore.savePick(
      scheduleId: scheduleId,
      encoded: pick.encoded,
      applicationCount: pick.applicationCount,
      categoryCount: pick.categoryCount,
    );
    await IosScreenTimeService.saveScheduleSelection(
      scheduleId: scheduleId,
      encoded: pick.encoded,
    );
    IsleAppLogService.log(
      'schedule ST pick $scheduleId apps=${pick.applicationCount} cats=${pick.categoryCount}',
    );
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    return true;
  }

  static bool shouldUseAdditiveOnly(String scheduleId) {
    final s = ScheduleActiveService.activeSchedulesNow()
        .where((e) => e.id == scheduleId)
        .firstOrNull;
    if (s == null) return false;
    return ScheduleActiveService.isScheduleActiveNow(s) && s.locked;
  }
}
