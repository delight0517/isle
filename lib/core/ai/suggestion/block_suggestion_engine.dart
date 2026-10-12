import '../../intervention/app_usage_limit_store.dart';
import '../../intervention/website_block_store.dart';
import '../block_chat/block_chat_models.dart';

/// 채팅 apply 성공 직후 현재 상태를 검사해 0~2개 능동 제안(SUGGEST proactive)을 만든다.
/// 이미 설정된 조합은 다시 제안하지 않는다(idempotent) — CHAT_SPEC §6 SUGGEST 규칙.
/// API 호출 없이 로컬 store 조회만 사용한다.
class BlockSuggestionEngine {
  BlockSuggestionEngine._();

  static Future<List<BlockChatSuggestion>> evaluate() async {
    await WebsiteBlockStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();

    final domains = WebsiteBlockStore.loadDomains();
    final limitRules = AppUsageLimitStore.loadRules();
    final suggestions = <BlockChatSuggestion>[];

    final instagramBlocked = domains.any((d) => d.contains('instagram'));
    final hasInstagramLimit = limitRules.any((r) => r.presetId == 'instagram');
    if (instagramBlocked && !hasInstagramLimit) {
      suggestions.add(
        const BlockChatSuggestion(
          id: 'suggest_instagram_app_limit',
          label: '인스타 앱 한도도 같이 설정할까요?',
          kind: 'proactive',
          answer: 'SNS는 막으셨는데 인스타 앱 자체 사용 한도는 아직이에요. '
              '"인스타 하루 30분" 처럼 말씀해 주시면 앱 사용 시간도 같이 관리돼요.',
        ),
      );
    }

    final tiktokBlocked = domains.any((d) => d.contains('tiktok'));
    final hasTiktokLimit = limitRules.any((r) => r.presetId == 'tiktok');
    if (tiktokBlocked && !hasTiktokLimit) {
      suggestions.add(
        const BlockChatSuggestion(
          id: 'suggest_tiktok_app_limit',
          label: '틱톡 앱 한도도 같이 설정할까요?',
          kind: 'proactive',
          answer: '틱톡 사이트는 막으셨는데 앱 자체 사용 한도는 아직이에요. '
              '"틱톡 하루 20분" 처럼 말씀해 주시면 앱 사용 시간도 같이 관리돼요.',
        ),
      );
    }

    return suggestions.take(2).toList();
  }
}
