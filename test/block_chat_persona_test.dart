import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/ai/block_chat/block_chat_persona_scenarios.dart';

void main() {
  test('persona catalog has 15 voices', () {
    expect(BlockChatPersonaScenarios.all.length, 15);
  });

  group('persona concern → persona_bundle', () {
    for (final p in BlockChatPersonaScenarios.all) {
      test(p.id, () async {
        final (plan, usedAi) = await BlockChatParser.parse(p.concern);
        expect(usedAi, false, reason: p.concern);
        expect(plan.action, 'persona_bundle', reason: p.concern);
        expect(plan.personaId, p.id, reason: p.concern);
        expect(plan.reply, contains(p.empathy.split(' ').first));
      });
    }
  });

  test('concern tone beats command-style when worried', () async {
    final (plan, _) = await BlockChatParser.parse(
      '숙제 해야 하는데 유튜브 추천만 계속 눌러요. 집중이 안 돼요',
    );
    expect(plan.action, 'persona_bundle');
    expect(plan.personaId, 'sua_homework_yt');
  });

  test('command style still works for daily scenarios', () async {
    final (plan, _) = await BlockChatParser.parse('숏츠 숨겨줘');
    expect(plan.action, 'toggle_shorts');
  });
}
