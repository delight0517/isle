import '../intervention/app_usage_limit_store.dart';
import '../intervention/platform_app_limit_service.dart';
import '../services/isle_app_log_service.dart';
import 'block_schedule_store.dart';
import 'models/schedule_enforcement_mode.dart';
import 'models/schedule_slot.dart';

/// 스케줄 enforcementMode에 맞춰 OS 앱 한도 등록
class ScheduleAppLimitSyncService {
  ScheduleAppLimitSyncService._();

  static Future<void> syncAll() async {
    if (!await PlatformAppLimitService.isSupported()) return;

    final rules = AppUsageLimitStore.loadRules();
    final schedules = {
      for (final s in BlockScheduleStore.loadAll()) s.id: s,
    };

    for (final rule in rules) {
      if (!rule.enabled || rule.iosFamilyActivityEncoded == null || rule.iosFamilyActivityEncoded!.isEmpty) {
        await PlatformAppLimitService.removeRule(rule.id);
        continue;
      }

      final scheduleId = rule.scheduleId;
      if (scheduleId == null) {
        await PlatformAppLimitService.syncRule(rule);
        continue;
      }

      final schedule = schedules[scheduleId];
      if (schedule == null || !schedule.enabled || schedule.slots.isEmpty) {
        await PlatformAppLimitService.removeRule(rule.id);
        continue;
      }

      final mode = schedule.enforcementMode;
      if (mode == ScheduleEnforcementMode.fullBlock) {
        await PlatformAppLimitService.removeRule(rule.id);
        continue;
      }

      final scope = mode.appliesLimitInSlot ? 'in_slot' : 'outside_slot';
      final ok = await PlatformAppLimitService.syncRuleScoped(
        rule: rule,
        scope: scope,
        slots: schedule.slots,
      );
      if (!ok) {
        IsleAppLogService.log(
          'schedule limit sync failed ${rule.id} scope=$scope',
          level: IsleLogLevel.warn,
        );
      }
    }
  }

  static List<Map<String, dynamic>> slotsToJson(List<ScheduleSlot> slots) =>
      slots
          .map(
            (s) => {
              'day': s.day,
              'startMinute': s.startMinute,
              'endMinute': s.endMinute,
            },
          )
          .toList();
}
