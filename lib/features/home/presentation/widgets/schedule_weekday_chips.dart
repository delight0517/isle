import 'package:flutter/material.dart';

import '../../../../core/block_schedule/models/schedule_slot.dart';
import '../../../../core/block_schedule/schedule_display_helper.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// 요일 칩 — 활성 요일 전부 하이라이트, 오늘은 테두리 강조
class ScheduleWeekdayChips extends StatelessWidget {
  const ScheduleWeekdayChips({super.key, required this.slots});

  final List<ScheduleSlot> slots;

  @override
  Widget build(BuildContext context) {
    final activeDays = ScheduleDisplayHelper.activeDayIndexes(slots);
    final today = ScheduleDisplayHelper.todayIndex();

    return Row(
      children: List.generate(7, (i) {
        final on = activeDays.contains(i);
        final isToday = i == today;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
            child: Container(
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on
                    ? (isToday ? IsleColors.ocean500 : IsleColors.ocean100)
                    : IsleColors.sand100,
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(
                        color: on ? Colors.white : IsleColors.ocean500,
                        width: 2,
                      )
                    : null,
              ),
              child: Text(
                ScheduleDisplayHelper.weekdayShort[i],
                style: IsleText.caption(
                  color: on
                      ? (isToday ? Colors.white : IsleColors.ocean700)
                      : IsleColors.muted,
                ).copyWith(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w800 : (on ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
