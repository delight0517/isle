import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';
import 'package:isle/core/ai/block_chat/block_chat_preview.dart';

/// "유튜브 뮤직 3일간 차단해줘"가 매일 00:00-23:59 영구 스케줄로 둔갑하던
/// 실사용 버그(2026-07-13, cage에서 먼저 발견된 것과 같은 클래스) — 모아의
/// `_parseQuickBlockNow`도 "지금부터"/"동안"/시간 단위만 인식하고 "N일"
/// 단위 기간 자체를 신호로 안 봤음. 회귀 방지.
void main() {
  test(
      '"유튜브 뮤직 3일간 차단해줘" (day-unit duration, no "지금"/"동안" cue) becomes '
      'a 3-day quick_block_now, not a shorter/permanent schedule', () async {
    final (plan, usedAi) = await BlockChatParser.parse('유튜브 뮤직 3일간 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'quick_block_now');
    expect(plan.limitPlatform, 'youtube_music');
    expect(plan.windowMinutes, 3 * 24 * 60);
    expect(plan.reply, contains('YouTube Music'));
    expect(plan.reply, contains('3일'));
  });

  test(
      'the confirm-card preview shows the real duration in days, not '
      'silently capped at 24 hours', () async {
    final (plan, _) = await BlockChatParser.parse('유튜브 뮤직 3일간 차단해줘');
    final bullets = BlockChatPreview.bullets(plan);
    expect(bullets, isNotEmpty);
    expect(bullets.join(' '), contains('3일'));
    expect(bullets.join(' '), isNot(contains('24시간')));
  });

  test('bare "지금부터 N시간" phrasing still works unaffected', () async {
    final (plan, usedAi) =
        await BlockChatParser.parse('유튜브 지금부터 3시간동안 차단해줘');
    expect(usedAi, false);
    expect(plan.action, 'quick_block_now');
    expect(plan.windowMinutes, 3 * 60);
  });
}
