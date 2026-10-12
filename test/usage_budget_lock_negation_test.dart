import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/ai/block_chat/block_chat_parser.dart';

/// 2026-07-06 실사용 로그(v1.6.0+298)에서 재현된 오파싱 회귀 테스트.
/// "카카오톡 잠금이 아니라 3분 사용 10분 lock으로 바꿔줘"
/// → 이전엔 daily_minutes:10(추측), cooldown/window:3(오탐)으로 잘못 파싱됨.
/// 의도: 3분 쓰면 10분 잠그기 (session=3, cooldown/window=10).
void main() {
  test('부정어("아니라") 뒤 restWord는 쿨다운으로 오인하지 않는다', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '그리고 카카오톡 잠금이 아니라 3분 사용 10분 lock으로 바꿔줘',
    );
    expect(usedAi, false, reason: plan.reply);
    expect(plan.sessionMinutes, 3, reason: '3분 사용');
    expect(plan.cooldownMinutes, 10, reason: '10분 lock — 3으로 오인되면 안 됨');
    expect(plan.windowMinutes, 10);
  });

  test('영어 "lock" 도 쿨다운 신호로 인식한다', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '인스타 5분 쓰면 15분 lock 되게 해줘',
    );
    expect(usedAi, false, reason: plan.reply);
    expect(plan.sessionMinutes, 5);
    expect(plan.cooldownMinutes, 15);
  });

  test('회귀: 정상적인 한국어 쉬는시간 표현은 계속 동작', () async {
    final (plan, usedAi) = await BlockChatParser.parse(
      '인스타 하루 45분, 15분씩 30분 쉬게',
    );
    expect(usedAi, false, reason: plan.reply);
    expect(plan.dailyMinutes, 45);
    expect(plan.sessionMinutes, 15);
    expect(plan.cooldownMinutes, 30);
  });
}
