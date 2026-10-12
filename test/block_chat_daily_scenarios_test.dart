import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/ai/block_chat/block_chat_daily_scenarios.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';

void main() {
  test('daily scenarios catalog has 18 items (15 + 3 compound, 2026-07-11)', () {
    expect(BlockChatDailyScenarios.all.length, 18);
    final ids = BlockChatDailyScenarios.all.map((s) => s.id).toSet();
    expect(ids.length, 18);
  });

  group('local parse — 18 daily scenarios', () {
    for (final scenario in BlockChatDailyScenarios.all) {
      test('${scenario.id} → ${scenario.action}', () async {
        final (plan, usedAi) = await BlockChatParser.parse(scenario.examplePrompt);
        expect(usedAi, false, reason: scenario.examplePrompt);
        expect(
          plan.action,
          scenario.action,
          reason: '「${scenario.examplePrompt}」',
        );
      });
    }
  });

  test('isle youtube morning schedule not keyword', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '매일 아침 10시30분까지는 isle 유튜브 차단해줘',
    );
    expect(usedAi, false);
    expect(plan.action, 'morning_schedule');
    expect(plan.blockIsleYoutube, true);
    expect(plan.endHour, 10);
    expect(plan.endMinute, 30);
  });

  test('safari schedule still works', () async {
    final (plan, _) = await BlockChatParser.parse('매일 9시까지 Safari 막아줘');
    expect(plan.action, 'morning_schedule');
    expect(plan.blockSafariNote, true);
    expect(plan.endHour, 9);
  });

  test('starcraft keyword still works', () async {
    final (plan, _) = await BlockChatParser.parse('스타크래프트 블락해줘');
    expect(plan.action, 'add_keyword');
    expect(plan.keyword, '스타크래프트');
  });

  test('remove url local parse', () async {
    final (plan, _) = await BlockChatParser.parse(
      'https://example.com/foo 블락 없애줘',
    );
    expect(plan.action, 'remove_url');
    expect(plan.removeUrl, contains('example.com'));
  });

  test('fuzzy remove schedule without exact name', () async {
    final (plan, _) = await BlockChatParser.parse('사파리 차단 스케줄 끄기');
    expect(plan.action, 'remove_schedule');
    expect(plan.scheduleQuery, 'safari');
  });

  test('morning youtube relax not habit pack', () async {
    final (plan, _) = await BlockChatParser.parse('아침에 유튜브 이제 보게 해줘');
    expect(plan.action, 'relax_block');
    expect(plan.relaxTarget, 'youtube');
  });

  test('safari pause not relax block', () async {
    final (plan, _) = await BlockChatParser.parse('Safari 10분만 풀어줘');
    expect(plan.action, 'safari_pause');
    expect(plan.pauseMinutes, 10);
  });
}
