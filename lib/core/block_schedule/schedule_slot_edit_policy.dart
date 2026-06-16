import 'models/block_schedule.dart';
import 'models/schedule_slot.dart';
import 'schedule_active_service.dart';

/// 스케줄 활성 중 시간표 편집 — 지금 시각 ±1시간 보호
class ScheduleSlotEditPolicy {
  ScheduleSlotEditPolicy._();

  /// 지금 시각 기준 편집 불가 구간(분)
  static const int bufferMinutes = 60;

  static bool isScheduleBlockActive(BlockSchedule schedule, [DateTime? now]) =>
      ScheduleActiveService.isScheduleActiveNow(schedule, now);

  static int _minuteOfDay(DateTime n) => n.hour * 60 + n.minute;

  static int _normalizeDay(int day) {
    if (day == 7) return 6;
    return day.clamp(0, 6);
  }

  /// 오늘 요일에 [start,end] 구간이 [rangeStart,rangeEnd]와 겹치는지 (자정 넘김 포함)
  static bool rangesOverlapMinutes(int start, int end, int rangeStart, int rangeEnd) {
    bool segOverlap(int a0, int a1, int b0, int b1) {
      if (a1 <= a0) {
        return segOverlap(a0, 24 * 60, b0, b1) || segOverlap(0, a1, b0, b1);
      }
      if (b1 <= b0) {
        return segOverlap(a0, a1, b0, 24 * 60) || segOverlap(a0, a1, 0, b1);
      }
      return a0 < b1 && b0 < a1;
    }

    return segOverlap(start, end, rangeStart, rangeEnd);
  }

  /// 지금 ±1시간 — 이 구간과 겹치는 오늘 슬롯/시간대는 수정·삭제 불가
  static bool touchesProtectedZoneToday({
    required Set<int> days,
    required int startMinute,
    required int endMinute,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final today = n.weekday - 1;
    final normalized = days.map(_normalizeDay).toSet();
    if (!normalized.contains(today)) return false;

    final m = _minuteOfDay(n);
    final protStart = (m - bufferMinutes).clamp(0, 24 * 60);
    final protEnd = (m + bufferMinutes).clamp(0, 24 * 60);
    return rangesOverlapMinutes(startMinute, endMinute, protStart, protEnd);
  }

  static bool canModifyTimeRange({
    required BlockSchedule schedule,
    required Set<int> days,
    required int startMinute,
    required int endMinute,
    DateTime? now,
  }) {
    if (!isScheduleBlockActive(schedule, now)) return true;
    return !touchesProtectedZoneToday(
      days: days,
      startMinute: startMinute,
      endMinute: endMinute,
      now: now,
    );
  }

  static bool canDeleteSlot({
    required BlockSchedule schedule,
    required ScheduleSlot slot,
    DateTime? now,
  }) {
    return canModifySlot(schedule: schedule, slot: slot, now: now);
  }

  static bool canModifySlot({
    required BlockSchedule schedule,
    required ScheduleSlot slot,
    DateTime? now,
  }) {
    return canModifyTimeRange(
      schedule: schedule,
      days: {_normalizeDay(slot.day)},
      startMinute: slot.startMinute,
      endMinute: slot.endMinute,
      now: now,
    );
  }

  /// 새 시간대 추가 — 활성 중에도 보호 구간 밖이면 허용
  static bool canAddTimeRange({
    required BlockSchedule schedule,
    required Set<int> days,
    required int startMinute,
    required int endMinute,
    DateTime? now,
  }) =>
      canModifyTimeRange(
        schedule: schedule,
        days: days,
        startMinute: startMinute,
        endMinute: endMinute,
        now: now,
      );

  static String protectedZoneLabel([DateTime? now]) {
    final n = now ?? DateTime.now();
    final m = _minuteOfDay(n);
    String h(int x) =>
        '${(x ~/ 60).toString().padLeft(2, '0')}:${(x % 60).toString().padLeft(2, '0')}';
    final protStart = (m - bufferMinutes).clamp(0, 24 * 60);
    final protEnd = (m + bufferMinutes).clamp(0, 24 * 60);
    return '지금 시각 기준 ${h(protStart)}~${h(protEnd)} 구간의 시간대는 편집할 수 없어요';
  }
}
