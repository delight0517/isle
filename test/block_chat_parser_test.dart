import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';

void main() {
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
}
