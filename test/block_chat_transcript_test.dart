import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/ai/block_chat/block_chat_models.dart';
import 'package:isle/core/ai/block_chat/block_chat_transcript_service.dart';
import 'package:isle/core/constants/app_release_info.dart';

void main() {
  test('full transcript includes turns and plan json', () {
    final messages = [
      const BlockChatMessage(
        role: BlockChatRole.user,
        text: '매일 9시까지 Safari 막아줘',
        createdAt: null,
      ),
      BlockChatMessage(
        role: BlockChatRole.assistant,
        text: '스케줄을 만들었어요.',
        usedAi: false,
        createdAt: DateTime.utc(2026, 6, 26, 12),
        plan: const BlockChatPlan(
          action: 'morning_schedule',
          blockSafariNote: true,
          endHour: 9,
        ),
        result: const BlockChatResult(
          summary: '스케줄을 만들었어요.',
          steps: [],
        ),
      ),
    ];

    final text = BlockChatTranscriptService.buildFullTranscriptForCursor(
      messages,
      exportedAt: DateTime.utc(2026, 6, 26, 12, 1),
    );

    expect(text, contains('=== Isle 차단 AI 챗'));
    expect(text, contains('Turn 1 · USER'));
    expect(text, contains('plan_action: morning_schedule'));
    expect(text, contains('block_safari'));
    expect(text, contains('=== END ==='));
  });

  test('bubble plain text includes role label', () {
    const m = BlockChatMessage(
      role: BlockChatRole.user,
      text: '숏츠 숨겨줘',
    );
    final text = BlockChatTranscriptService.messagePlainText(m);
    expect(text, contains('[사용자]'));
    expect(text, contains('숏츠 숨겨줘'));
  });

  test('bubble plain text always includes app version (cage에서 이식, 07-11)', () {
    const m = BlockChatMessage(
      role: BlockChatRole.assistant,
      text: '적용했어요.',
    );
    final text = BlockChatTranscriptService.messagePlainText(m);
    expect(text, contains(AppReleaseInfo.label));
  });
}
