import '../block_schedule/block_schedule_store.dart';
import '../block_schedule/schedule_active_service.dart';
import 'models/youtube_schedule_rule.dart';

/// 레거시 API — 내부는 [BlockScheduleStore] (블루프린트 v2)
class YoutubeScheduleLockStore {
  YoutubeScheduleLockStore._();

  static Future<void> ensureOpen() async => BlockScheduleStore.ensureOpen();

  static bool get isEnabled => BlockScheduleStore.masterEnabled;

  static bool isLockedNow([DateTime? at]) {
    if (!BlockScheduleStore.masterEnabled) return false;
    return ScheduleActiveService.isYoutubeWebViewBlockedNow(at);
  }

  static YoutubeScheduleRule? activeRuleNow([DateTime? at]) {
    final active = ScheduleActiveService.activeSchedulesNow(at);
    if (active.isEmpty) return null;
    final s = active.first;
    if (s.slots.isEmpty) return null;
    final slot = s.slots.first;
    return YoutubeScheduleRule(
      id: s.id,
      weekdays: {slot.day + 1},
      startMinutes: slot.startMinute,
      endMinutes: slot.endMinute,
      enabled: s.enabled,
    );
  }
}
