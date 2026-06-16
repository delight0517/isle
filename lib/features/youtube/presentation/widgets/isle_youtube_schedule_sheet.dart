import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/block_schedule/isle_youtube_schedule_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/isle_sheet.dart';

/// 수동 — 매일 아침까지 Isle 유튜브 차단
Future<void> showIsleYoutubeScheduleSheet(BuildContext context) async {
  var endTime = const TimeOfDay(hour: 10, minute: 30);

  await showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setLocal) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Isle 유튜브 스케줄', style: IsleText.subtitle(color: IsleColors.ocean900)),
              const SizedBox(height: 6),
              Text(
                '매일 0시부터 선택한 시각까지 앱 안 유튜브를 막아요.\n'
                'iPhone YouTube 앱은 스케줄 편집에서 별도 선택.',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('차단 해제 시각'),
                subtitle: Text(
                  '매일 ${endTime.hour}시 ${endTime.minute > 0 ? '${endTime.minute}분' : ''}까지',
                  style: IsleText.body(color: IsleColors.ocean700),
                ),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: endTime,
                    helpText: '몇 시까지 막을까요?',
                  );
                  if (picked != null) setLocal(() => endTime = picked);
                },
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final schedule = await IsleYoutubeScheduleService.applyMorningBlock(
                    endHour: endTime.hour,
                    endMinute: endTime.minute,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('「${schedule.name}」 스케줄 적용됨')),
                  );
                  context.push('/settings/block-schedules/${schedule.id}');
                },
                icon: const Icon(Icons.check),
                label: const Text('스케줄 적용'),
              ),
              TextButton(
                onPressed: () => context.push('/settings/block-schedules'),
                child: const Text('스케줄 목록 보기'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
