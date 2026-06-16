import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// 차단 스케줄 편집 — 단계별 섹션 헤더
class ScheduleEditSectionHeader extends StatelessWidget {
  const ScheduleEditSectionHeader({
    super.key,
    required this.step,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final int step;
  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: IsleColors.ocean100,
          child: Text(
            '$step',
            style: IsleText.caption(color: IsleColors.ocean700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: IsleColors.ocean700),
                    const SizedBox(width: 6),
                  ],
                  Expanded(child: Text(title, style: IsleText.subtitle())),
                ],
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
