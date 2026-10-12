import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/block/models/premade_block_pack.dart';
import '../../../../core/block/premade_block_pack_entry_effects.dart';
import '../../../../core/block/premade_block_pack_removal_service.dart';
import '../../../../core/block/premade_block_pack_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/isle_sheet.dart';
import '../../../feed/providers/feed_provider.dart';
import '../../../../core/youtube/blocked_channel_store.dart';
import '../../../../core/youtube/blocked_url_store.dart';
import '../../../../core/youtube/content_filter_store.dart';

Future<void> showPremadeBlockPackBrowseSheet(
  BuildContext context, {
  required PremadeBlockPack pack,
}) =>
    showIsleModalSheet<void>(
      context: context,
      builder: (ctx) => PremadeBlockPackBrowseSheet(pack: pack),
    );

class PremadeBlockPackBrowseSheet extends ConsumerStatefulWidget {
  const PremadeBlockPackBrowseSheet({super.key, required this.pack});

  final PremadeBlockPack pack;

  @override
  ConsumerState<PremadeBlockPackBrowseSheet> createState() =>
      _PremadeBlockPackBrowseSheetState();
}

class _PremadeBlockPackBrowseSheetState extends ConsumerState<PremadeBlockPackBrowseSheet> {
  final _search = TextEditingController();
  String _query = '';
  String? _busyDedupeKey;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PremadeBlockPackEntry> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.pack.entries;
    return widget.pack.entries.where((e) {
      final hay = '${e.pattern} ${e.kind} ${e.note ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _exclude(PremadeBlockPackEntry entry) async {
    if (_busyDedupeKey != null) return;
    final applied = PremadeBlockPackService.isPackApplied(widget.pack.packId);
    if (!applied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 프리셋을 적용해 주세요')),
      );
      return;
    }

    final status = PremadeBlockPackService.entryStatus(
      packId: widget.pack.packId,
      entry: entry,
    );
    if (status == PremadePackEntryStatus.excluded) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('프리셋에서 제외'),
        content: Text(
          '「${entry.pattern}」을(를) 차단 목록에서 빼고, '
          '앞으로 자동 동기화해도 다시 추가하지 않습니다.\n\n'
          '직접 추가한 다른 차단은 유지돼요.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: IsleColors.danger),
            child: const Text('제외'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busyDedupeKey = entry.dedupeKey);
    try {
      final result = await PremadeBlockPackRemovalService.excludeEntry(
        packId: widget.pack.packId,
        entry: entry,
      );
      await ref.read(blockedChannelsProvider.notifier).reload();
      await ref.read(blockedKeywordsProvider.notifier).reload();
      await ref.read(blockedUrlsProvider.notifier).reload();
      await ref.read(feedProvider.notifier).removeBlockedFromFeed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.summary(widget.pack.displayName))),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('제외 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyDedupeKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final applied = PremadeBlockPackService.isPackApplied(widget.pack.packId);
    final filtered = _filtered;
    final excludedCount = widget.pack.entries
        .where(
          (e) =>
              PremadeBlockPackService.entryStatus(packId: widget.pack.packId, entry: e) ==
              PremadePackEntryStatus.excluded,
        )
        .length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            IsleSize.scrollBottomPadding(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.pack.displayName, style: IsleText.subtitle()),
              const SizedBox(height: 4),
              Text(
                applied
                    ? '${widget.pack.entryCount}개 · 제외 $excludedCount · 검색·개별 해제 가능'
                    : '${widget.pack.entryCount}개 · 미적용 — 목록만 미리보기',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: '채널·도메인·키워드 검색',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 10),
              Text(
                '${filtered.length}개 표시',
                style: IsleText.badge(color: IsleColors.muted),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final status = PremadeBlockPackService.entryStatus(
                      packId: widget.pack.packId,
                      entry: entry,
                    );
                    return _EntryRow(
                      entry: entry,
                      status: status,
                      busy: _busyDedupeKey == entry.dedupeKey,
                      onExclude: applied && status == PremadePackEntryStatus.active
                          ? () => _exclude(entry)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.status,
    required this.busy,
    this.onExclude,
  });

  final PremadeBlockPackEntry entry;
  final PremadePackEntryStatus status;
  final bool busy;
  final VoidCallback? onExclude;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PremadePackEntryStatus.active => ('차단 중', IsleColors.ocean700),
      PremadePackEntryStatus.excluded => ('제외됨', IsleColors.muted),
      PremadePackEntryStatus.pending => ('미반영', const Color(0xFFB45309)),
      PremadePackEntryStatus.notApplied => ('미적용', IsleColors.muted),
    };

    return Material(
      color: IsleColors.sand100,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.pattern,
                    style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    PremadeBlockPackEntryEffects.kindLabelKo(entry.kind) +
                        (entry.note != null ? ' · ${entry.note}' : ''),
                    style: IsleText.caption(color: IsleColors.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(label, style: IsleText.badge(color: color)),
            ),
            if (onExclude != null) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: '프리셋에서 제외',
                onPressed: busy ? null : onExclude,
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.remove_circle_outline, color: IsleColors.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
