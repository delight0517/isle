import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'models/schedule_enforcement_mode.dart';
import 'quick_block_service.dart';
import 'schedule_active_service.dart';
import 'url_rules/schedule_rule_enforcement.dart';

/// enforcementMode에 따른 쉴드·한도 적용 판단
class ScheduleEnforcementPolicy {
  ScheduleEnforcementPolicy._();

  static Iterable<BlockSchedule> _enabledSchedules() => BlockScheduleStore.loadAll().where(
        (s) =>
            s.id != QuickBlockService.presetScheduleId &&
            s.enabled &&
            s.slots.isNotEmpty,
      );

  /// 지금 Screen Time 쉴드·YouTube 도메인 차단에 쓸 스케줄
  static List<BlockSchedule> shieldSchedulesNow([DateTime? at]) {
    if (!BlockScheduleStore.masterEnabled) return [];
    final now = at ?? DateTime.now();
    return ScheduleActiveService.activeSchedulesNow(now).where(
      (s) => s.enforcementMode.appliesShieldInSlot,
    ).toList();
  }

  static List<String> mergedDomainsForShieldNow([DateTime? at]) {
    return ScheduleRuleEnforcement.mergedExpandedHostsNow(at);
  }

  /// DeviceActivity 슬롯 모니터 — 완전 차단 모드만 (limitInSlot은 한도 DA만 사용)
  static List<BlockSchedule> deviceActivitySchedules() => _enabledSchedules()
      .where((s) => s.enforcementMode.appliesShieldInSlot)
      .toList();

}
