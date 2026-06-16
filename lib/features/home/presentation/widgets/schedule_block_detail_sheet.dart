import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/block_schedule/schedule_block_explain_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/explorer/explorer_site.dart';
import '../../../../core/navigation/isle_routes.dart';
import '../../../../shared/widgets/isle_sheet.dart';

/// 스케줄·차단 이유 더보기 — 어떤 스케줄·요소가 막는지
Future<void> showScheduleBlockDetailSheet(
  BuildContext context, {
  String? url,
  ExplorerSite? site,
  String? previewMessage,
  bool inAppExplorer = true,
}) async {
  final report = url != null && url.trim().isNotEmpty
      ? ScheduleBlockExplainService.explainUrl(
          url,
          inAppExplorer: inAppExplorer,
        )
      : ScheduleBlockExplainService.explainSite(
          site ?? ExplorerSite.youtube,
          url: url,
          inAppExplorer: inAppExplorer,
        );

  if (!context.mounted) return;

  await showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, scroll) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: ListView(
          controller: scroll,
          children: [
            Text('왜 막혔나요?', style: IsleText.title(color: IsleColors.ocean900)),
            const SizedBox(height: 6),
            if (previewMessage != null)
              Text(
                previewMessage,
                style: IsleText.caption(color: Colors.red.shade800),
              ),
            if (report.url != null) ...[
              const SizedBox(height: 8),
              Text(
                report.url!,
                style: IsleText.caption(color: IsleColors.muted).copyWith(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SummaryCard(report: report),
            const SizedBox(height: 16),
            Text('적용 중인 요소', style: IsleText.subtitle(color: IsleColors.ocean900)),
            const SizedBox(height: 8),
            if (report.items.isEmpty)
              Text('기록된 차단 요소가 없어요.', style: IsleText.body(color: IsleColors.muted))
            else
              ...report.items.map((item) => _ReasonTile(item: item)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: IsleSize.minTouchTarget,
              child: FilledButton.icon(
                onPressed: () async {
                  final text = _formatCopy(report, previewMessage);
                  await Clipboard.setData(ClipboardData(text: text));
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('차단 이유 복사됨 — Cursor에 붙여넣기')),
                    );
                  }
                },
                icon: const Icon(Icons.content_copy),
                label: const Text('이유 복사 (개발자용)'),
              ),
            ),
            if (report.primaryScheduleId != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: IsleSize.minTouchTarget,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push(IsleRoutes.blockScheduleEdit(report.primaryScheduleId!));
                  },
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text('해당 스케줄 편집'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: IsleSize.minTouchTarget,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/settings/block-schedules');
                },
                child: const Text('스케줄 목록 전체'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _formatCopy(ScheduleBlockExplainReport report, String? preview) {
  final buf = StringBuffer('=== Isle 차단 이유 ===\n');
  if (preview != null) buf.writeln(preview);
  if (report.url != null) buf.writeln('URL: ${report.url}');
  buf.writeln('요약: ${report.summary}\n');
  for (final i in report.items) {
    buf.writeln('[${i.layer}] ${i.title}');
    buf.writeln(i.detail);
    if (i.fixHint != null) buf.writeln('→ ${i.fixHint}');
    buf.writeln();
  }
  return buf.toString();
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});

  final ScheduleBlockExplainReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: report.blocked ? const Color(0xFFFFEBEE) : IsleColors.ocean100,
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
        border: Border.all(
          color: report.blocked ? Colors.red.shade200 : IsleColors.ocean500.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            report.blocked ? Icons.block : Icons.check_circle_outline,
            color: report.blocked ? Colors.red.shade700 : IsleColors.ocean700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.blocked ? '지금 차단됨' : '차단 조건 없음',
                  style: IsleText.subtitle(
                    color: report.blocked ? Colors.red.shade900 : IsleColors.ocean900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.summary,
                  style: IsleText.body(color: IsleColors.ocean900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.item});

  final ScheduleBlockExplainItem item;

  IconData get _icon => switch (item.iconName) {
        'schedule' => Icons.schedule,
        'apps' => Icons.apps,
        'timer' => Icons.timer,
        'public_off' => Icons.public_off,
        'link_off' => Icons.link_off,
        'play_disabled' => Icons.play_disabled,
        'shield' => Icons.shield,
        'phone_iphone' => Icons.phone_iphone,
        'hourglass' => Icons.hourglass_bottom,
        'check' => Icons.check_circle,
        _ => Icons.info_outline,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icon, size: 20, color: IsleColors.ocean700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item.title, style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.detail,
              style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
            ),
            if (item.fixHint != null) ...[
              const SizedBox(height: 8),
              Text(
                '💡 ${item.fixHint}',
                style: IsleText.caption(color: IsleColors.ocean700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
