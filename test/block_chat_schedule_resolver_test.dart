import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/ai/block_chat/block_chat_schedule_resolver.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/block_schedule.dart';
import 'package:isle/core/block_schedule/models/schedule_enforcement_mode.dart';
import 'package:isle/core/block_schedule/models/schedule_slot.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_block_chat_sched');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
  });

  setUp(() async {
    for (final s in BlockScheduleStore.loadAll()) {
      await BlockScheduleStore.delete(s.id);
    }
  });

  test('resolver matches youtube keyword without exact name', () async {
    await BlockScheduleStore.upsert(
      BlockSchedule(
        id: 'yt_morning',
        name: '아침 Isle 유튜브 (AI)',
        enabled: true,
        enforcementMode: ScheduleEnforcementMode.fullBlock,
        blockIsleInApp: true,
        slots: const [
          ScheduleSlot(day: 0, startMinute: 0, endMinute: 600),
        ],
      ),
    );
    await BlockScheduleStore.upsert(
      BlockSchedule(
        id: 'safari_morning',
        name: '아침 Safari 차단',
        enabled: true,
        enforcementMode: ScheduleEnforcementMode.fullBlock,
        blockIsleInApp: true,
        slots: const [
          ScheduleSlot(day: 0, startMinute: 0, endMinute: 540),
        ],
      ),
    );

    final match = BlockChatScheduleResolver.resolve('유튜브');
    expect(match, isNotNull);
    expect(match!.schedule.id, 'yt_morning');
  });

  test('resolver empty query prefers enabled schedule', () async {
    await BlockScheduleStore.upsert(
      BlockSchedule(
        id: 'only_one',
        name: '저녁 SNS (AI)',
        enabled: true,
        enforcementMode: ScheduleEnforcementMode.fullBlock,
        slots: const [
          ScheduleSlot(day: 0, startMinute: 0, endMinute: 480),
        ],
      ),
    );

    final match = BlockChatScheduleResolver.resolve(null);
    expect(match?.schedule.id, 'only_one');
  });

  group('parser schedule mutation', () {
    test('remove schedule by keyword without exact name', () async {
      final (plan, usedAi) =
          await BlockChatParser.parse('아침 유튜브 스케줄 꺼줘');
      expect(usedAi, false);
      expect(plan.action, 'remove_schedule');
      expect(plan.scheduleQuery, '유튜브');
    });

    test('rename schedule local parse', () async {
      final (plan, _) = await BlockChatParser.parse(
        '아침 유튜브 스케줄 이름을 저녁 집중으로 바꿔줘',
      );
      expect(plan.action, 'rename_schedule');
      expect(plan.scheduleQuery, '유튜브');
      expect(plan.scheduleNewName, '저녁 집중');
    });

    test('update end time local parse — bare ambiguous hour asks to clarify '
        'AM/PM instead of silently guessing', () async {
      final (plan, _) =
          await BlockChatParser.parse('유튜브 스케줄 11시까지로 바꿔줘');
      expect(plan.action, 'explain');
      expect(plan.reply, contains('23'));
    });

    test('update end time local parse — unambiguous 24h hour applies directly',
        () async {
      final (plan, _) =
          await BlockChatParser.parse('유튜브 스케줄 23시까지로 바꿔줘');
      expect(plan.action, 'update_schedule_time');
      expect(plan.scheduleQuery, '유튜브');
      expect(plan.endHour, 23);
    });

    test('add saturday local parse', () async {
      final (plan, _) =
          await BlockChatParser.parse('아침 스케줄 토요일도 추가해줘');
      expect(plan.action, 'add_schedule_days');
      expect(plan.scheduleQuery, '아침');
      expect(plan.days, contains(5));
    });
  });
}
