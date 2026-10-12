import 'package:flutter/material.dart';

import '../../../../core/block_schedule/schedule_block_user_message.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/explorer/explorer_site.dart';
import '../../../../core/navigation/isle_routes.dart';
import '../../../../core/navigation/schedule_sheet_navigation.dart';
import '../../../../core/services/isle_app_log_service.dart';
import '../../../../shared/widgets/isle_sheet.dart';
import 'schedule_block_detail_sheet.dart';
import 'schedule_block_week_preview.dart';

/// 스케줄·시청 한도·차단으로 진입이 막혔을 때 — 친절한 시트
Future<void> showScheduleBlockEntrySheet(
  BuildContext context, {
  ExplorerSite? site,
  String? url,
  String? legacyMessage,
  bool inAppExplorer = true,
}) async {
  final copy = ScheduleBlockUserMessage.entryCopy(
    site: site,
    url: url,
    legacyMessage: legacyMessage,
    inAppExplorer: inAppExplorer,
  );

  if (!context.mounted) return;

  final isLimit = copy.isYoutubeDailyLimit;
  final headerColors = isLimit
      ? [const Color(0xFFB71C1C), const Color(0xFFE53935)]
      : [IsleColors.ocean900, IsleColors.ocean700];
  final headerIcon = isLimit ? Icons.hourglass_disabled : Icons.schedule;

  await showIsleModalSheet<void>(
    context: context,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.88;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 4, 20, 20 + MediaQuery.viewPaddingOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (isLimit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(Icons.lock_clock,
                          size: 18, color: Colors.red.shade700),
                      const SizedBox(width: 6),
                      Text(
                        '스케줄 차단이 아니에요 · 시청 한도',
                        style: IsleText.caption(color: Colors.red.shade800)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: headerColors,
                  ),
                  borderRadius: BorderRadius.circular(IsleSize.cardRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child:
                              Icon(headerIcon, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            copy.title,
                            style: IsleText.subtitle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    if (copy.usageChip != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          copy.usageChip!,
                          style: IsleText.body(color: Colors.white)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ] else if (copy.scheduleName != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '「${copy.scheduleName}」',
                          style: IsleText.body(color: Colors.white)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      copy.body,
                      style: IsleText.body(
                              color: Colors.white.withValues(alpha: 0.92))
                          .copyWith(height: 1.45),
                    ),
                    if (copy.endsHint != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isLimit
                                ? Icons.timer_outlined
                                : Icons.hourglass_bottom,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              copy.endsHint!,
                              style: IsleText.caption(
                                  color: Colors.white.withValues(alpha: 0.9)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (copy.scheduleId != null) ...[
                ScheduleBlockWeekPreview(scheduleId: copy.scheduleId!),
                const SizedBox(height: 14),
              ],
              if (copy.layerLabel != null)
                Text(
                  '이유: ${copy.layerLabel}',
                  style: IsleText.caption(color: IsleColors.muted),
                ),
              const SizedBox(height: 6),
              Text(
                '💡 ${copy.fixHint}',
                style: IsleText.body(color: IsleColors.ocean900)
                    .copyWith(height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: IsleSize.minTouchTarget,
                child: FilledButton.icon(
                  onPressed: () {
                    final route = copy.primaryRoute ??
                        (copy.scheduleId != null
                            ? IsleRoutes.blockScheduleEditOutsideShell(
                                copy.scheduleId!)
                            : IsleRoutes.blockSchedulesOutsideShell);
                    IsleAppLogService.log('BlockEntrySheet: primary → $route');
                    dismissSheetThenPush(ctx, context, route);
                  },
                  icon: Icon(
                      isLimit ? Icons.timer_outlined : Icons.edit_calendar),
                  label: Text(
                    copy.primaryButtonLabel ??
                        (copy.scheduleId != null ? '이 스케줄 편집' : '스케줄 목록'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: IsleSize.minTouchTarget,
                child: OutlinedButton.icon(
                  onPressed: () {
                    IsleAppLogService.log('BlockEntrySheet: detail tapped');
                    Navigator.of(ctx, rootNavigator: true).pop();
                    Future.delayed(const Duration(milliseconds: 280), () {
                      if (!context.mounted) return;
                      showScheduleBlockDetailSheet(
                        context,
                        url: url,
                        site: site,
                        previewMessage: copy.oneLine,
                        inAppExplorer: inAppExplorer,
                      );
                    });
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('자세한 차단 이유'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                child: const Text('닫기'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
