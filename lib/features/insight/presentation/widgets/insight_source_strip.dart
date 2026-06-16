import 'package:flutter/material.dart';

import '../../../../core/insight/knowledge_visual_system.dart';

/// 상단 미니멀 소스 — 로고·채널명만 (썸네일 없음)
class InsightSourceStrip extends StatelessWidget {
  const InsightSourceStrip({
    super.key,
    required this.channelName,
    this.sourceLabel = 'YouTube',
    this.showYoutubeMark = true,
  });

  final String channelName;
  final String sourceLabel;
  final bool showYoutubeMark;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = KnowledgeVisual.mutedFg(b);

    return Row(
      children: [
        if (showYoutubeMark) ...[
          const Icon(Icons.play_circle_filled, size: 16, color: Color(0xFFFF0000)),
          const SizedBox(width: 6),
        ],
        Text(
          sourceLabel.toUpperCase(),
          style: KnowledgeVisual.editorialMonoHint(color: fg),
        ),
        if (channelName.trim().isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('·', style: KnowledgeVisual.editorialCaption(color: fg)),
          ),
          Expanded(
            child: Text(
              channelName.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KnowledgeVisual.editorialCaption(color: fg),
            ),
          ),
        ],
      ],
    );
  }
}
