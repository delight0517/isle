import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ai/block_chat/block_chat_models.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// 채팅 적용 결과 아래 표시되는 퀵 리플라이 칩 줄 — FAQ(반응형) 또는 능동 제안.
/// CHAT_SPEC SUGGEST: API 호출 없이 로컬 canned 텍스트만 다룬다.
class BlockChatQuickReplyBar extends StatelessWidget {
  const BlockChatQuickReplyBar({
    super.key,
    required this.suggestions,
    required this.onTap,
  });

  final List<BlockChatSuggestion> suggestions;
  final ValueChanged<BlockChatSuggestion> onTap;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in suggestions)
            _QuickReplyChip(
              suggestion: s,
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(s);
              },
            ),
        ],
      ),
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  const _QuickReplyChip({required this.suggestion, required this.onTap});

  final BlockChatSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isFaq = suggestion.kind == 'faq';
    final color = isFaq ? IsleColors.ocean700 : IsleColors.gold500;
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFaq ? Icons.help_outline : Icons.lightbulb_outline,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                suggestion.label,
                style: IsleText.caption(color: color)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
