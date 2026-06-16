import 'package:flutter/material.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/youtube/creative_analytics/models/narrative_report.dart';

/// 도입–전개–CTA 컬러 바 타임라인
class NarrativeTimelineBar extends StatelessWidget {
  const NarrativeTimelineBar({
    super.key,
    required this.acts,
    required this.totalSeconds,
  });

  final List<NarrativeAct> acts;
  final int totalSeconds;

  static Color _colorFor(String phase) {
    switch (phase) {
      case 'hook':
        return const Color(0xFFE1306C);
      case 'body':
        return const Color(0xFF2B4A8C);
      case 'twist':
        return const Color(0xFFFF9800);
      case 'cta':
        return const Color(0xFF00C389);
      default:
        return const Color(0xFF90A4AE);
    }
  }

  static String _label(String phase) {
    switch (phase) {
      case 'hook':
        return '훅';
      case 'body':
        return '본론';
      case 'twist':
        return '반전';
      case 'cta':
        return 'CTA';
      default:
        return phase;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = totalSeconds > 0 ? totalSeconds : acts.fold<int>(0, (m, a) => m + (a.endSec - a.startSec));
    if (acts.isEmpty || total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 28,
            width: double.infinity,
            child: Row(
              children: [
                for (final act in acts)
                  Expanded(
                    flex: (act.endSec - act.startSec).clamp(1, total),
                    child: Container(color: _colorFor(act.phase)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: acts.map((a) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _colorFor(a.phase),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_label(a.phase)} ${a.startSec}–${a.endSec}s',
                  style: IsleText.caption(),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
