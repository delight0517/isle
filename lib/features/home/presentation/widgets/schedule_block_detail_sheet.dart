import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/block_schedule/schedule_block_explain_service.dart';
import '../../../../core/block_schedule/schedule_block_relax_service.dart';
import '../../../../core/youtube/youtube_access_guard.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/explorer/explorer_site.dart';
import '../../../../core/navigation/isle_routes.dart';
import '../../../../core/navigation/schedule_sheet_navigation.dart';
import '../../../../shared/widgets/isle_sheet.dart';
import 'schedule_block_week_preview.dart';

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
      builder: (_, scroll) => _ScheduleBlockDetailBody(
        scrollController: scroll,
        hostContext: context,
        sheetContext: ctx,
        report: report,
        previewMessage: previewMessage,
      ),
    ),
  );
}

class _ScheduleBlockDetailBody extends StatefulWidget {
  const _ScheduleBlockDetailBody({
    required this.scrollController,
    required this.hostContext,
    required this.sheetContext,
    required this.report,
    this.previewMessage,
  });

  final ScrollController scrollController;
  final BuildContext hostContext;
  final BuildContext sheetContext;
  final ScheduleBlockExplainReport report;
  final String? previewMessage;

  @override
  State<_ScheduleBlockDetailBody> createState() =>
      _ScheduleBlockDetailBodyState();
}

class _ScheduleBlockDetailBodyState extends State<_ScheduleBlockDetailBody> {
  late List<ScheduleBlockExplainItem> _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.report.items);
  }

  Future<void> _relax(ScheduleBlockExplainItem item) async {
    if (_busy || !item.isRelaxable) return;
    setState(() => _busy = true);
    try {
      final result = await ScheduleBlockRelaxService.relaxItem(item);
      if (!mounted) return;
      if (!widget.hostContext.mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(widget.hostContext);
      messenger?.showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      if (result.applied) {
        setState(() => _items.remove(item));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmRelax(ScheduleBlockExplainItem item) async {
    if (!item.isRelaxable) return false;
    final label = item.relaxLabel ?? '이 규칙 끄기';
    final ok = await showDialog<bool>(
      context: widget.sheetContext,
      builder: (dctx) => AlertDialog(
        title: Text(label),
        content: Text(
          '「${item.scheduleName ?? item.title}」\n\n'
          '${item.detail}\n\n'
          '설정 잠금이 켜져 있으면 ${item.scheduleName != null ? '대기 후' : ''} 자동으로 적용돼요.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(dctx, true), child: Text(label)),
        ],
      ),
    );
    if (ok != true) return false;
    await _relax(item);
    return _items.every((i) => i != item);
  }

  List<Widget> _buildItemSections(ScheduleBlockExplainReport report) {
    final url = report.url ?? '';
    final isYt = url.contains('youtube.com') || url.contains('youtu.be');
    final watch = ScheduleBlockExplainService.watchItemsFor(
      _items,
      inAppExplorer: true,
      isYoutubeUrl: isYt,
    );
    final browser = ScheduleBlockExplainService.browserSeparateItemsFor(
      _items,
      inAppExplorer: true,
      isYoutubeUrl: isYt,
    );

    Widget tile(ScheduleBlockExplainItem item) => _ReasonTile(
          key: ValueKey('${item.layer}-${item.scheduleId}-${item.title}'),
          item: item,
          busy: _busy,
          onRelax: () => _relax(item),
          onConfirmDismiss: () => _confirmRelax(item),
        );

    final out = <Widget>[];

    if (watch.isEmpty) {
      out.add(
        Text(
          YoutubeAccessGuard.canWatchInIsleApp
              ? '지금 Isle 시청 기준으로는 막는 규칙이 없어요'
              : 'Isle 유튜브 스케줄 또는 시청 한도를 확인하세요',
          style: IsleText.body(color: IsleColors.muted),
        ),
      );
    } else {
      out.addAll(watch.map(tile));
    }

    if (browser.isNotEmpty) {
      out.addAll([
        const SizedBox(height: 16),
        Text('Safari·브라우저 (별도)',
            style: IsleText.subtitle(color: IsleColors.ocean900)),
        Text(
          '로그인용 Safari 오버레이·도메인 쉴드 — Isle 유튜브 시청과 무관',
          style: IsleText.caption(color: IsleColors.muted),
        ),
        const SizedBox(height: 8),
        ...browser.map(tile),
      ]);
    }

    if (watch.isEmpty && browser.isEmpty && _items.isEmpty) {
      out.add(Text('기록된 차단 요소가 없어요.',
          style: IsleText.body(color: IsleColors.muted)));
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: ListView(
        controller: widget.scrollController,
        children: [
          Text('왜 막혔나요?', style: IsleText.title(color: IsleColors.ocean900)),
          const SizedBox(height: 8),
          Text(
            'Isle 안 유튜브 시청은 한 가지 기준이에요: ③ Isle 유튜브 · 시청 한도. '
            'Safari·도메인·타임락은 아래 「별도 설정」이에요.',
            style:
                IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: IsleColors.ocean100.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '예전 Safari 로그인 오버레이 우회는 「Safari·브라우저」쪽에서 막고, '
              'Isle /youtube 재생 여부는 위 시청 기준만 봅니다.',
              style: IsleText.caption(color: IsleColors.ocean900)
                  .copyWith(height: 1.4),
            ),
          ),
          if (widget.previewMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              widget.previewMessage!,
              style: IsleText.body(color: IsleColors.ocean900),
            ),
          ],
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
          if (report.primaryScheduleId != null) ...[
            const SizedBox(height: 14),
            ScheduleBlockWeekPreview(scheduleId: report.primaryScheduleId!),
          ],
          const SizedBox(height: 16),
          Text('Isle 유튜브 시청',
              style: IsleText.subtitle(color: IsleColors.ocean900)),
          Text(
            '이것만 보면 돼요 — 스케줄 「Isle 유튜브」·시청 한도',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 8),
          ..._buildItemSections(report),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: IsleSize.minTouchTarget,
            child: FilledButton.icon(
              onPressed: () async {
                final text = _formatCopy(report, widget.previewMessage, _items);
                await Clipboard.setData(ClipboardData(text: text));
                if (widget.sheetContext.mounted) {
                  ScaffoldMessenger.of(widget.sheetContext).showSnackBar(
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
                onPressed: () => dismissSheetThenPush(
                  widget.sheetContext,
                  widget.hostContext,
                  IsleRoutes.blockScheduleEditOutsideShell(
                    report.primaryScheduleId!,
                  ),
                ),
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
              onPressed: () => dismissSheetThenPush(
                widget.sheetContext,
                widget.hostContext,
                IsleRoutes.blockSchedulesOutsideShell,
              ),
              child: const Text('스케줄 목록 전체'),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCopy(
  ScheduleBlockExplainReport report,
  String? preview,
  List<ScheduleBlockExplainItem> items,
) {
  final buf = StringBuffer('=== Isle 차단 이유 ===\n');
  if (preview != null) buf.writeln(preview);
  if (report.url != null) buf.writeln('URL: ${report.url}');
  buf.writeln('요약: ${report.summary}\n');
  for (final i in items) {
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
          color: report.blocked
              ? Colors.red.shade200
              : IsleColors.ocean500.withValues(alpha: 0.3),
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
                    color: report.blocked
                        ? Colors.red.shade900
                        : IsleColors.ocean900,
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
  const _ReasonTile({
    super.key,
    required this.item,
    required this.busy,
    required this.onRelax,
    required this.onConfirmDismiss,
  });

  final ScheduleBlockExplainItem item;
  final bool busy;
  final VoidCallback onRelax;
  final Future<bool> Function() onConfirmDismiss;

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

  Widget _card() {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: item.isRelaxable && !busy ? onRelax : null,
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
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
                    child: Text(
                      item.title,
                      style:
                          IsleText.body().copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (item.isRelaxable)
                    const Icon(
                      Icons.chevron_left,
                      size: 18,
                      color: IsleColors.muted,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.detail,
                style: IsleText.caption(color: IsleColors.muted)
                    .copyWith(height: 1.4),
              ),
              if (item.relaxLabel != null) ...[
                const SizedBox(height: 8),
                Text(
                  '← ${item.relaxLabel}',
                  style: IsleText.caption(color: IsleColors.ocean700),
                ),
              ] else if (item.fixHint != null) ...[
                const SizedBox(height: 8),
                Text(
                  '💡 ${item.fixHint}',
                  style: IsleText.caption(color: IsleColors.ocean700),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = _card();
    if (!item.isRelaxable) {
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: child);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: key ?? ValueKey(item.title),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => onConfirmDismiss(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: IsleColors.danger,
            borderRadius: BorderRadius.circular(IsleSize.cardRadius),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.delete_outline, color: Colors.white),
              const SizedBox(height: 4),
              Text(
                item.relaxLabel ?? '끄기',
                style: IsleText.caption(color: Colors.white),
              ),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}
