import 'package:flutter/material.dart';

import '../../../../core/block_schedule/schedule_display_helper.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/intervention/screen_time_selection_summary.dart';

/// 스케줄별 차단 대상 아이콘 — 이름·타깃 기준 (전역 Screen Time 첫 아이콘만 보이는 문제 완화)
class ScheduleTargetIconsRow extends StatelessWidget {
  const ScheduleTargetIconsRow({
    super.key,
    required this.scheduleId,
    required this.visuals,
    this.usesGlobalFallback = false,
  });

  final String scheduleId;
  final List<ScheduleTargetVisual> visuals;
  final bool usesGlobalFallback;

  @override
  Widget build(BuildContext context) {
    if (visuals.isEmpty) {
      return Text(
        '차단할 앱을 아래 「차단 앱 변경」에서 고르세요',
        style: IsleText.caption(color: Colors.black54),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: visuals.map((v) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: v.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: v.color.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(v.icon, size: 18, color: v.color),
                  const SizedBox(width: 6),
                  Text(
                    v.label,
                    style: IsleText.caption().copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        if (usesGlobalFallback) ...[
          const SizedBox(height: 6),
          Text(
            'iPhone 앱 목록은 다른 스케줄과 공유 중 — 이 카드 제목·칩이 실제 대상이에요',
            style: IsleText.caption(color: Colors.black45).copyWith(height: 1.3),
          ),
        ],
      ],
    );
  }

  static bool globalFallbackFor(String scheduleId) =>
      ScreenTimeSelectionSummary.usesGlobalFallback(scheduleId);
}
