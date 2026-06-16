import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'models/schedule_slot.dart';
import 'quick_block_service.dart';
import 'schedule_target_access_guard.dart';

/// §4 — 지금 활성인 스케줄 ID 목록
class ScheduleActiveService {
  ScheduleActiveService._();

  static int _minuteOfDay(DateTime now) => now.hour * 60 + now.minute;

  static int _blueprintDay(DateTime now) => now.weekday - 1;

  static bool _slotActive(ScheduleSlot slot, DateTime now) {
    if (slot.day != _blueprintDay(now)) return false;
    return slot.coversMinute(_minuteOfDay(now));
  }

  static bool isScheduleActiveNow(BlockSchedule schedule, [DateTime? at]) {
    if (!schedule.enabled) return false;
    final now = at ?? DateTime.now();
    if (schedule.slots.isEmpty) return false;
    return schedule.slots.any((s) => _slotActive(s, now));
  }

  static List<BlockSchedule> activeSchedulesNow([DateTime? at]) {
    if (!BlockScheduleStore.masterEnabled) return [];
    final now = at ?? DateTime.now();
    final base = BlockScheduleStore.loadAll()
        .where((s) => s.id != QuickBlockService.presetScheduleId && isScheduleActiveNow(s, now))
        .toList();
    if (QuickBlockService.activeSessions(now).isNotEmpty) {
      final preset = BlockScheduleStore.loadAll()
          .where((s) => s.id == QuickBlockService.presetScheduleId)
          .firstOrNull;
      if (preset != null && !base.any((s) => s.id == preset.id)) {
        base.add(preset.copyWith(enabled: true));
      }
    }
    return base;
  }

  static List<String> activeScheduleIdsNow([DateTime? at]) =>
      activeSchedulesNow(at).map((s) => s.id).toList();

  static List<String> mergedDomainsForActiveNow([DateTime? at]) {
    final set = <String>{};
    for (final s in activeSchedulesNow(at)) {
      set.addAll(s.domains.map((d) => d.toLowerCase().trim()));
    }
    return set.where((d) => d.isNotEmpty).toList();
  }

  /// Isle WebView 유튜브 잠금 — 「Isle · YouTube 시청」 타깃을 켠 스케줄 슬롯에서만.
  static bool isYoutubeWebViewBlockedNow([DateTime? at]) {
    return ScheduleTargetAccessGuard.isIsleYoutubeBlocked;
  }
}
