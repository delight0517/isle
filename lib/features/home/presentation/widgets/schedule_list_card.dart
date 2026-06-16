import 'package:flutter/material.dart';

import '../../../../core/block_schedule/models/block_schedule.dart';
import '../../../../core/block_schedule/schedule_display_helper.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/intervention/screen_time_selection_summary.dart';
import '../../../../shared/widgets/screen_time_selection_preview.dart';
import 'schedule_target_icons_row.dart';
import 'schedule_weekday_chips.dart';

/// 차단 홈·설정 스케줄 목록 — 동일 카드 UI
class ScheduleListCard extends StatelessWidget {
  const ScheduleListCard({
    super.key,
    required this.schedule,
    required this.active,
    required this.onTap,
    required this.onEditApps,
    this.trailing,
    this.showEditAppsButton = true,
  });

  final BlockSchedule schedule;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onEditApps;
  final Widget? trailing;
  final bool showEditAppsButton;

  @override
  Widget build(BuildContext context) {
    final scheduleId = schedule.id;
    final encoded = ScreenTimeSelectionSummary.encodedForSchedule(scheduleId);
    final todayLine = ScheduleDisplayHelper.todayStatusLine(schedule);
    final timeLine = ScheduleDisplayHelper.formatScheduleTimes(schedule.slots);
    final targets = ScheduleDisplayHelper.targetVisualsForSchedule(schedule);
    final globalFb = ScheduleTargetIconsRow.globalFallbackFor(scheduleId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: active ? const Color(0xFFFFEBEE) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active ? IsleColors.danger.withValues(alpha: 0.35) : IsleColors.ocean100,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            schedule.name,
                            style: IsleText.subtitle(color: IsleColors.ocean900),
                          ),
                        ),
                        if (active)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: IsleColors.danger,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '지금 잠금',
                              style: IsleText.caption(color: Colors.white)
                                  .copyWith(fontWeight: FontWeight.w800, fontSize: 10),
                            ),
                          ),
                        if (!schedule.enabled)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: IsleColors.muted.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '꺼짐',
                              style: IsleText.caption(color: IsleColors.muted).copyWith(fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      todayLine,
                      style: IsleText.body(color: active ? IsleColors.danger : IsleColors.ocean700)
                          .copyWith(fontWeight: FontWeight.w700, height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    ScheduleTargetIconsRow(
                      scheduleId: scheduleId,
                      visuals: targets,
                      usesGlobalFallback: globalFb,
                    ),
                    if (targets.isEmpty &&
                        encoded != null &&
                        !globalFb &&
                        encoded.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ScreenTimeSelectionPreview(
                        encoded: encoded,
                        textFallbackLabels: const [],
                        height: 34,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(timeLine, style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35)),
                    if (showEditAppsButton) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onEditApps,
                          icon: const Icon(Icons.apps_outage, size: 16),
                          label: const Text('차단 앱 변경'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, IsleSize.minTouchTarget),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    ScheduleWeekdayChips(slots: schedule.slots),
                  ],
                ),
              ),
              trailing ??
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.chevron_right, color: IsleColors.muted, size: 20),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
