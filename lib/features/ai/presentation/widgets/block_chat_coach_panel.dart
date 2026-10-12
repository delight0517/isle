import 'package:flutter/material.dart';

import '../../../../core/ai/block_chat/block_chat_models.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/navigation/schedule_overlay_navigation.dart';

/// 적용 후 활용법 · 다음 한 단계 추천
class BlockChatCoachPanel extends StatelessWidget {
  const BlockChatCoachPanel({
    super.key,
    required this.guide,
    this.onTryChatPrompt,
  });

  final BlockChatCoachGuide guide;
  final void Function(String prompt)? onTryChatPrompt;

  @override
  Widget build(BuildContext context) {
    if (guide.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width * 0.94;

    return Container(
      width: width,
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IsleColors.ocean500.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            color: IsleColors.ocean100.withValues(alpha: 0.5),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: IsleColors.ocean700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '조금씩 같이 조절해요',
                    style: IsleText.subtitle(color: IsleColors.ocean900)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (guide.usageInsight.isNotEmpty) ...[
                  Text(
                    guide.usageInsight,
                    style: IsleText.body(color: IsleColors.ocean900)
                        .copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 14),
                ],
                if (guide.howToUse.isNotEmpty) ...[
                  _sectionLabel(Icons.menu_book_outlined, '방금 켠 기능 활용법'),
                  const SizedBox(height: 8),
                  for (final tip in guide.howToUse) _TipTile(tip: tip),
                  const SizedBox(height: 14),
                ],
                if (guide.recommendations.isNotEmpty) ...[
                  _sectionLabel(Icons.auto_awesome_outlined, '다음 한 단계'),
                  const SizedBox(height: 8),
                  for (final rec in guide.recommendations)
                    _RecommendationTile(
                      rec: rec,
                      onTryChatPrompt: onTryChatPrompt,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: IsleColors.ocean700),
        const SizedBox(width: 6),
        Text(
          label,
          style: IsleText.caption(color: IsleColors.ocean700)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _TipTile extends StatelessWidget {
  const _TipTile({required this.tip});

  final BlockChatCoachTip tip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IsleColors.ocean100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tip.title,
              style: IsleText.body(color: IsleColors.ocean900)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              tip.body,
              style: IsleText.caption(color: IsleColors.ocean700)
                  .copyWith(height: 1.4),
            ),
            if (tip.route != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => pushRoutePreferRoot(context, tip.route!),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                        IsleSize.minTouchTarget, IsleSize.minTouchTarget),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(tip.routeLabel ?? '열기'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.rec,
    this.onTryChatPrompt,
  });

  final BlockChatCoachRecommendation rec;
  final void Function(String prompt)? onTryChatPrompt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rec.title,
              style: IsleText.body(color: IsleColors.ocean900)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              rec.reason,
              style: IsleText.caption(color: IsleColors.muted)
                  .copyWith(height: 1.4),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (rec.chatPrompt != null && onTryChatPrompt != null)
                  FilledButton.tonal(
                    onPressed: () => onTryChatPrompt!(rec.chatPrompt!),
                    child: const Text('챗으로 적용'),
                  ),
                if (rec.route != null)
                  OutlinedButton(
                    onPressed: () => pushRoutePreferRoot(context, rec.route!),
                    child: Text(rec.routeLabel ?? '열기'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
