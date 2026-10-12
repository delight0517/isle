import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/block_schedule/models/block_schedule.dart';
import 'package:isle/core/block_schedule/models/schedule_slot.dart';
import 'package:isle/core/block_schedule/schedule_display_helper.dart';

void main() {
  test('normalizeDay keeps blueprint Sunday as 6', () {
    expect(ScheduleDisplayHelper.normalizeDay(6), 6);
    expect(ScheduleDisplayHelper.normalizeDay(7), 6);
    expect(ScheduleDisplayHelper.normalizeDay(0), 0);
  });

  test('formatScheduleTimes compresses daily slots', () {
    final slots = [
      for (var d = 0; d < 7; d++)
        ScheduleSlot(day: d, startMinute: 9 * 60, endMinute: 23 * 60),
    ];
    final text = ScheduleDisplayHelper.formatScheduleTimes(slots);
    expect(text, contains('매일'));
    expect(text, contains('09:00'));
    expect(text, isNot(contains('외')));
  });

  test('activeDayIndexes lights all weekdays', () {
    final slots = [
      for (var d = 0; d < 7; d++) ScheduleSlot(day: d, startMinute: 0, endMinute: 60),
    ];
    expect(ScheduleDisplayHelper.activeDayIndexes(slots).length, 7);
  });

  test('uniqueTargetKeys counts domain schedules separately', () {
    final schedules = [
      BlockSchedule(
        id: 'a',
        name: 'safari',
        slots: const [ScheduleSlot(day: 0, startMinute: 540, endMinute: 1380)],
        domains: const ['apple.com'],
      ),
      BlockSchedule(
        id: 'b',
        name: 'YouTube 전체 차단',
        slots: const [ScheduleSlot(day: 0, startMinute: 0, endMinute: 1380)],
        domains: BlockSchedule.defaultYoutubeDomains,
      ),
    ];
    final keys = ScheduleDisplayHelper.uniqueTargetKeysForSchedules(schedules);
    expect(keys, contains('domains'));
    expect(keys.length, greaterThanOrEqualTo(1));
  });

  test('targetVisuals uses domains not schedule name', () {
    final s = BlockSchedule(
      id: 't',
      name: 'YouTube 전체 차단',
      slots: const [ScheduleSlot(day: 0, startMinute: 0, endMinute: 23 * 60)],
      domains: BlockSchedule.defaultYoutubeDomains,
    );
    final v = ScheduleDisplayHelper.targetVisualsForSchedule(s);
    expect(v.any((e) => e.key == 'domains'), isTrue);
    expect(v.any((e) => e.label == 'YouTube'), isFalse);
  });

  test('configuredSummaryLine empty when nothing selected', () {
    final s = BlockSchedule(
      id: 'empty',
      name: 'safari',
      slots: const [ScheduleSlot(day: 0, startMinute: 0, endMinute: 60)],
    );
    expect(
      ScheduleDisplayHelper.configuredSummaryLine(s),
      contains('아무 것도 안 고름'),
    );
  });

  test('activeScheduleChipLabel shows safety line time', () {
    final s = BlockSchedule(
      id: 'safety',
      name: '안전 라인 — 야간 완전 차단',
      slots: [
        for (var d = 0; d < 7; d++)
          ScheduleSlot(day: d, startMinute: 21 * 60 + 30, endMinute: 10 * 60),
      ],
      isSafetyBaseline: true,
    );
    final text = ScheduleDisplayHelper.activeScheduleChipLabel(
      s,
      at: DateTime(2026, 7, 16, 23, 0),
    );
    expect(text, contains('안전 라인'));
    expect(text, contains('10:00'));
  });
}
