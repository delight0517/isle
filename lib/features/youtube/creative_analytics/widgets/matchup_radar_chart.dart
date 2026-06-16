import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// 두 채널 훅·WPM·전개 속도 레이더 비교
class MatchupRadarChart extends StatelessWidget {
  const MatchupRadarChart({
    super.key,
    required this.labelA,
    required this.labelB,
    required this.hookSecA,
    required this.hookSecB,
    required this.wpmA,
    required this.wpmB,
    required this.bodyRatioA,
    required this.bodyRatioB,
  });

  final String labelA;
  final String labelB;
  final int hookSecA;
  final int hookSecB;
  final int wpmA;
  final int wpmB;
  /// 본론 구간 비율 0~1
  final double bodyRatioA;
  final double bodyRatioB;

  @override
  Widget build(BuildContext context) {
    final maxHook = 30.0;
    final maxWpm = 220.0;

    List<RadarEntry> entriesA() => [
          RadarEntry(value: (hookSecA / maxHook).clamp(0.05, 1.0)),
          RadarEntry(value: (wpmA / maxWpm).clamp(0.05, 1.0)),
          RadarEntry(value: bodyRatioA.clamp(0.05, 1.0)),
          RadarEntry(value: 0.7),
        ];

    List<RadarEntry> entriesB() => [
          RadarEntry(value: (hookSecB / maxHook).clamp(0.05, 1.0)),
          RadarEntry(value: (wpmB / maxWpm).clamp(0.05, 1.0)),
          RadarEntry(value: bodyRatioB.clamp(0.05, 1.0)),
          RadarEntry(value: 0.7),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('채널 매치업 레이더', style: IsleText.subtitle()),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              tickCount: 4,
              ticksTextStyle: IsleText.caption(color: IsleColors.muted),
              getTitle: (index, angle) {
                const titles = ['훅 길이', '말속도', '본론 비중', '편집 템포'];
                return RadarChartTitle(text: titles[index % titles.length]);
              },
              radarBorderData: const BorderSide(color: IsleColors.ocean100),
              gridBorderData: const BorderSide(color: IsleColors.ocean100),
              tickBorderData: const BorderSide(color: Colors.transparent),
              dataSets: [
                RadarDataSet(
                  fillColor: const Color(0xFFE1306C).withValues(alpha: 0.25),
                  borderColor: const Color(0xFFE1306C),
                  entryRadius: 2,
                  dataEntries: entriesA(),
                ),
                RadarDataSet(
                  fillColor: IsleColors.ocean500.withValues(alpha: 0.2),
                  borderColor: IsleColors.ocean700,
                  entryRadius: 2,
                  dataEntries: entriesB(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _legend(const Color(0xFFE1306C), labelA),
            const SizedBox(width: 16),
            _legend(IsleColors.ocean700, labelB),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: IsleText.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
