import '../intervention/app_usage_limit_store.dart';
import '../intervention/models/app_usage_limit_rule.dart';
import 'models/schedule_enforcement_mode.dart';

/// 시간 한도 모드 전환 시 기본 규칙 존재 여부
class ScheduleLimitSetupHelper {
  ScheduleLimitSetupHelper._();

  static bool needsLimitRules(String scheduleId, ScheduleEnforcementMode mode) {
    if (mode == ScheduleEnforcementMode.fullBlock) return false;
    return AppUsageLimitStore.loadRules()
        .where((r) => r.scheduleId == scheduleId && !isAutoSeededPlaceholder(r))
        .isEmpty;
  }

  /// 예전 버전이 모드 전환 시 자동 넣던 Instagram 8분 템플릿(비활성·앱 미선택).
  static bool isAutoSeededPlaceholder(AppUsageLimitRule r) =>
      r.enabled == false &&
      r.presetId == 'instagram' &&
      r.minutesPerWindow == 8 &&
      r.windowMinutes == 60 &&
      (r.iosFamilyActivityEncoded == null || r.iosFamilyActivityEncoded!.isEmpty);

  /// 저장소·UI 목록에서 제거.
  static Future<void> pruneAutoSeededPlaceholders() async {
    final all = AppUsageLimitStore.loadRules();
    final pruned = all.where((r) => !isAutoSeededPlaceholder(r)).toList();
    if (pruned.length != all.length) {
      await AppUsageLimitStore.saveRules(pruned);
    }
  }
}
