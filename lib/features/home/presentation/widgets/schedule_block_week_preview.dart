import 'package:flutter/material.dart';

import '../../../../core/block_schedule/block_schedule_store.dart';
import '../../../../core/block_schedule/schedule_display_helper.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../settings/presentation/widgets/schedule_window_sheet.dart';
import 'schedule_weekday_chips.dart';

/// 차단 시트 — 월~일 요일·시간대 미리보기
class ScheduleBlockWeekPreview extends StatelessWidget {
  const ScheduleBlockWeekPreview({super.key, required this.scheduleId});

  final String scheduleId;

  @override
  Widget build(BuildContext context) {
    final schedule = BlockScheduleStore.loadAll()
        .where((e) => e.id == scheduleId)
        .firstOrNull;
    if (schedule == null) {
      return Text(
        '스케줄을 찾지 못했어요. 목록에서 확인해 주세요.',
        style: IsleText.caption(color: IsleColors.muted),
      );
    }

    final lines = ScheduleWindowSheet.summarize(schedule.slots);
    final todayLine = ScheduleDisplayHelper.todayStatusLine(schedule);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IsleColors.ocean100.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IsleColors.ocean500.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '「${schedule.name}」 요일·시간',
            style: IsleText.subtitle(color: IsleColors.ocean900),
          ),
          const SizedBox(height: 8),
          ScheduleWeekdayChips(slots: schedule.slots),
          const SizedBox(height: 8),
          Text(todayLine, style: IsleText.caption(color: IsleColors.ocean700)),
          if (lines.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '시간 슬롯 없음 — 편집에서 요일·시간을 추가하세요',
              style: IsleText.caption(color: IsleColors.muted),
            ),
          ] else
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.schedule, size: 15, color: IsleColors.ocean500),
                    const SizedBox(width: 6),
                    Expanded(child: Text(line, style: IsleText.caption(color: IsleColors.ocean900))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
