import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ai/ai_config_store.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../ai/presentation/widgets/ai_key_auto_setup_card.dart';

/// 설정 홈 — AI API가 왜 필요한지 한눈에
class AiSetupPromoCard extends StatelessWidget {
  const AiSetupPromoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final configured = AiConfigStore.isConfigured;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: IsleColors.ocean100,
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(IsleSize.cardRadius),
          onTap: () => context.push('/settings/ai-hub'),
          onLongPress: () => showApiKeyPasteSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: IsleSize.minTouchTarget,
                      height: IsleSize.minTouchTarget,
                      decoration: BoxDecoration(
                        color: IsleColors.gold500.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_awesome, color: IsleColors.ocean700),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI 센터', style: IsleText.subtitle(color: IsleColors.ocean900)),
                          Text(
                            configured ? '연결됨 · 탭해서 모델·예산 확인' : 'API 키를 넣으면 요약·기사·장르 분석이 켜져요',
                            style: IsleText.caption(color: IsleColors.ocean700),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      configured ? Icons.check_circle : Icons.chevron_right,
                      color: configured ? IsleColors.success : IsleColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _guideRow(Icons.summarize_outlined, '피드·라이브러리 요약'),
                _guideRow(Icons.article_outlined, '「관심」→ 맞춤 기사 생성'),
                _guideRow(Icons.category_outlined, '유튜브 채널 장르 분류'),
                const SizedBox(height: 8),
                Text(
                  '키는 이 기기 Keychain에만 저장됩니다. 붙여넣기만 하면 OpenAI·Gemini·OpenRouter 등 자동 연결. 길게 누르면 붙여넣기 시트.',
                  style: IsleText.caption(color: IsleColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _guideRow(IconData icon, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: IsleColors.ocean500),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: IsleText.body(color: IsleColors.ocean900))),
          ],
        ),
      );
}
