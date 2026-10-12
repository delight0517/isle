import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/block_schedule/pomodoro_night_schedule_sync.dart';

void main() {
  test('imports only enabled night rules and converts Sunday-first days', () {
    final slots = PomodoroNightScheduleSync.nightSlots({
      'settings': {
        'lockSchedule': [
          {
            'enabled': true,
            'startMin': 1290,
            'endMin': 600,
            'days': [0, 1],
          },
          {
            'enabled': true,
            'startMin': 0,
            'endMin': 420,
            'days': [6],
          },
          {
            'enabled': true,
            'startMin': 600,
            'endMin': 1200,
            'days': [2],
          },
          {
            'enabled': false,
            'startMin': 1320,
            'endMin': 420,
            'days': [3],
          },
          {
            'enabled': true,
            'startMin': 60,
            'endMin': 60,
            'days': [4]
          },
        ],
      },
    });

    expect(slots.map((slot) => [slot.day, slot.startMinute, slot.endMinute]), [
      [6, 1290, 600], // Sunday -> Isle day 6
      [0, 1290, 600], // Monday -> Isle day 0
      [5, 0, 420], // Saturday -> Isle day 5
    ]);
  });

  test('empty days means every day, as in Auto Pomodoro', () {
    final slots = PomodoroNightScheduleSync.nightSlots({
      'lockSchedule': [
        {'enabled': true, 'startMin': 1380, 'endMin': 360, 'days': []},
      ],
    });
    expect(slots.map((slot) => slot.day).toSet(), {0, 1, 2, 3, 4, 5, 6});
  });
}
