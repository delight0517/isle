import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/block_schedule/models/block_schedule.dart';
import 'package:isle/core/block_schedule/models/schedule_slot.dart';
import 'package:isle/core/block_schedule/schedule_slot_edit_policy.dart';

void main() {
  test('cannot modify slot overlapping now±1h while schedule active', () {
    final now = DateTime(2026, 5, 15, 17, 2); // Fri 17:02
    final schedule = BlockSchedule(
      id: 's1',
      name: 'Test',
      enabled: true,
      slots: [
        ScheduleSlot(day: 4, startMinute: 9 * 60, endMinute: 23 * 60),
      ],
    );
    final slot = schedule.slots.first;
    expect(
      ScheduleSlotEditPolicy.canModifySlot(schedule: schedule, slot: slot, now: now),
      isFalse,
    );
  });

  test('can modify morning slot while evening block active', () {
    final now = DateTime(2026, 5, 15, 17, 2);
    final schedule = BlockSchedule(
      id: 's1',
      name: 'Test',
      enabled: true,
      slots: [
        ScheduleSlot(day: 4, startMinute: 9 * 60, endMinute: 23 * 60),
        ScheduleSlot(day: 4, startMinute: 6 * 60, endMinute: 8 * 60),
      ],
    );
    final morning = schedule.slots[1];
    expect(
      ScheduleSlotEditPolicy.canModifySlot(schedule: schedule, slot: morning, now: now),
      isTrue,
    );
  });

  test('can modify any slot when schedule inactive', () {
    final now = DateTime(2026, 5, 15, 10, 0);
    final schedule = BlockSchedule(
      id: 's1',
      name: 'Test',
      enabled: true,
      slots: [
        ScheduleSlot(day: 4, startMinute: 20 * 60, endMinute: 23 * 60),
      ],
    );
    expect(
      ScheduleSlotEditPolicy.canModifySlot(
        schedule: schedule,
        slot: schedule.slots.first,
        now: now,
      ),
      isTrue,
    );
  });
}
