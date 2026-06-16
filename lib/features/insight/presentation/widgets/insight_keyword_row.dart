import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/insight/knowledge_visual_system.dart';

/// 하단 지식 키워드 — 액센트 블루만 사용
class InsightKeywordRow extends StatelessWidget {
  const InsightKeywordRow({
    super.key,
    required this.keywords,
    this.max = 6,
  });

  final List<String> keywords;
  final int max;

  @override
  Widget build(BuildContext context) {
    final tags = keywords.where((k) => k.trim().isNotEmpty).take(max).toList();
    if (tags.isEmpty) return const SizedBox.shrink();

    final b = Theme.of(context).brightness;
    final onDark = b == Brightness.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((raw) {
        final label = raw.startsWith('#') ? raw : '#$raw';
        return Container(
          constraints: const BoxConstraints(minHeight: IsleSize.minTouchTarget / 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: onDark
                ? KnowledgeVisual.intelligentBlue.withValues(alpha: 0.18)
                : KnowledgeVisual.intelligentBlueSoft,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: KnowledgeVisual.intelligentBlue.withValues(alpha: onDark ? 0.45 : 0.25),
            ),
          ),
          child: Text(
            label,
            style: KnowledgeVisual.editorialCaption(
              color: onDark ? KnowledgeVisual.intelligentBlueMuted : KnowledgeVisual.intelligentBlue,
            ),
          ),
        );
      }).toList(),
    );
  }
}
