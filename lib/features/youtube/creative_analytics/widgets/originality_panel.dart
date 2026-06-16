import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/youtube/creative_analytics/models/narrative_report.dart';

/// 「구조는 훔치되, 알맹이는 내 것」 — 복제 덫 방지
class OriginalityPanel extends StatelessWidget {
  const OriginalityPanel({super.key, required this.report});

  final NarrativeReport report;

  @override
  Widget build(BuildContext context) {
    final tips = report.originalityPrompts;
    final checklist = report.differentiationChecklist;
    if (tips.isEmpty && checklist.isEmpty) return const SizedBox.shrink();

    return Card(
      color: IsleColors.gold500.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: IsleColors.gold500, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '나만의 차별점 한 스푼',
                    style: IsleText.subtitle(color: IsleColors.ocean900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '데이터는 결과일 뿐, 매력은 직접 넣어야 해요. 구조만 복제하면 양산형 채널이 됩니다.',
              style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
            ),
            if (tips.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final t in tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: IsleColors.ocean700)),
                      Expanded(child: Text(t, style: IsleText.body())),
                    ],
                  ),
                ),
            ],
            if (checklist.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('체크리스트', style: IsleText.caption(color: IsleColors.ocean700)),
              const SizedBox(height: 6),
              for (final c in checklist)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(c, style: IsleText.body()),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
