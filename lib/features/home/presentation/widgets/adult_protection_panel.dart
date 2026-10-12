import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/block/models/pending_rule_removal.dart';
import '../../../../core/block/premade_block_pack_removal_service.dart';
import '../../../../core/block/premade_block_pack_service.dart';
import '../../../../core/block/rule_pending_removal_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/safety/adult_protection_service.dart';
import '../../../../shared/widgets/rule_removal_lock_controls.dart';
import '../../../../core/youtube/blocked_channel_store.dart';
import '../../../../core/youtube/blocked_url_store.dart';
import '../../../../core/youtube/content_filter_store.dart';
import '../../../feed/providers/feed_provider.dart';
import '../../../youtube/presentation/widgets/premade_block_pack_browse_sheet.dart';

/// 성인 보호 단일 UI — 끔 / 기본(SafeSearch·주요 URL) / 강화(4VPN 통합 팩)
class AdultProtectionPanel extends ConsumerStatefulWidget {
  const AdultProtectionPanel({super.key, this.compact = false, this.onChanged});

  final bool compact;
  final VoidCallback? onChanged;

  @override
  ConsumerState<AdultProtectionPanel> createState() => _AdultProtectionPanelState();
}

class _AdultProtectionPanelState extends ConsumerState<AdultProtectionPanel> {
  bool _busy = false;
  bool _updateAvailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshUpdateFlag());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(rulePendingRemovalsProvider.notifier).refresh());
    });
  }

  Future<void> _refreshUpdateFlag() async {
    if (!AdultProtectionService.isFull || !AdultProtectionService.fullPackApplied) {
      if (mounted) setState(() => _updateAvailable = false);
      return;
    }
    final available = await PremadeBlockPackService.isPackUpdateAvailableForPackId(
      AdultProtectionService.packId,
    );
    if (mounted) setState(() => _updateAvailable = available);
  }

  Future<void> _selectTier(AdultProtectionTier tier) async {
    if (_busy || AdultProtectionService.tier == tier) return;

    if (tier == AdultProtectionTier.full) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('성인 보호 · 강화'),
          content: const Text(
            '4VPN 통합 필터 팩(웹·YouTube 400+)을 한 번에 적용합니다.\n\n'
            '· YouTube 채널 / 키워드 / URL\n'
            '· Safari 사이트\n\n'
            '기본 보호(SafeSearch · 주요 URL)도 함께 켜져요.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('강화 켜기'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result = await AdultProtectionService.setTier(tier);
      if (!mounted) return;
      if (result.packApplied) {
        await ref.read(blockedChannelsProvider.notifier).reload();
        await ref.read(blockedKeywordsProvider.notifier).reload();
        await ref.read(blockedUrlsProvider.notifier).reload();
        await ref.read(feedProvider.notifier).removeBlockedFromFeed();
      }
      if (result.message != null) {
        messenger.showSnackBar(SnackBar(content: Text(result.message!)));
      }
      setState(() {});
      unawaited(_refreshUpdateFlag());
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('성인 보호 설정 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _browseFullPack() async {
    if (_busy) return;
    final pack = await PremadeBlockPackService.loadAdultPack();
    if (!mounted || pack == null) return;
    await showPremadeBlockPackBrowseSheet(context, pack: pack);
  }

  Future<void> _syncFull() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result = await AdultProtectionService.syncFullPack();
      if (!mounted) return;
      await ref.read(blockedChannelsProvider.notifier).reload();
      await ref.read(blockedKeywordsProvider.notifier).reload();
      await ref.read(blockedUrlsProvider.notifier).reload();
      await ref.read(feedProvider.notifier).removeBlockedFromFeed();
      if (result.message != null) {
        messenger.showSnackBar(SnackBar(content: Text(result.message!)));
      }
      setState(() {});
      unawaited(_refreshUpdateFlag());
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('동기화 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelPendingRemoval() async {
    final pending = AdultProtectionService.pendingPackRemoval;
    if (pending == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('강화 해제 예약 취소'),
        content: Text(
          '강화 팩 해제가 '
          '${RulePendingRemovalService.formatRemaining(pending.remaining())} 예정이에요.\n'
          '취소할까요?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('아니요')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('예약 취소'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(rulePendingRemovalsProvider.notifier).cancel(
          PendingRuleRemovalKind.premadePack,
          PremadeBlockPackRemovalService.resolvePackId(AdultProtectionService.packId),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('강화 해제 예약을 취소했어요')),
    );
    setState(() {});
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tier = AdultProtectionService.tier;
    final pending = AdultProtectionService.pendingPackRemoval;
    final update = _updateAvailable;

    if (widget.compact) {
      return SegmentedButton<AdultProtectionTier>(
        segments: AdultProtectionTier.values
            .map(
              (t) => ButtonSegment(
                value: t,
                label: Text(t.labelKo, style: IsleText.badge()),
                enabled: !_busy,
              ),
            )
            .toList(),
        selected: {tier},
        onSelectionChanged: _busy
            ? null
            : (s) {
                if (s.isNotEmpty) unawaited(_selectTier(s.first));
              },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.visibility_off, size: 20, color: IsleColors.danger),
            const SizedBox(width: 8),
            Text('성인 보호', style: IsleText.subtitle()),
            if (_busy) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '하나로 통합 — 기본(SafeSearch·주요 URL) · 강화(400+ 규칙). '
          '스케줄·설정·보호 필터 모두 여기 기준.',
          style: IsleText.caption(color: IsleColors.muted),
        ),
        const SizedBox(height: 12),
        SegmentedButton<AdultProtectionTier>(
          segments: AdultProtectionTier.values
              .map(
                (t) => ButtonSegment(
                  value: t,
                  label: Text(t.labelKo),
                  enabled: !_busy && pending == null,
                ),
              )
              .toList(),
          selected: {tier},
          onSelectionChanged: _busy || pending != null
              ? null
              : (s) {
                  if (s.isNotEmpty) unawaited(_selectTier(s.first));
                },
        ),
        if (pending != null) ...[
          const SizedBox(height: 10),
          Material(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _busy ? null : _cancelPendingRemoval,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: Colors.orange.shade900, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '강화 해제 예약 · '
                        '${RulePendingRemovalService.formatRemaining(pending.remaining())} · 탭해 취소',
                        style: IsleText.badge(color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (tier == AdultProtectionTier.full && pending == null) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: IsleSize.minTouchTarget,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _browseFullPack,
              icon: const Icon(Icons.list_alt_rounded, size: 20),
              label: const Text('성인 사이트·채널 목록 · 검색'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: IsleSize.minTouchTarget,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _syncFull,
              icon: Icon(update ? Icons.system_update_alt : Icons.sync, size: 20),
              label: Text(update ? '강화 팩 업데이트 동기화' : '강화 팩 동기화'),
            ),
          ),
        ] else if (tier != AdultProtectionTier.off && pending == null) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: IsleSize.minTouchTarget,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _browseFullPack,
              icon: const Icon(Icons.preview_outlined, size: 20),
              label: const Text('강화 팩 목록 미리보기'),
            ),
          ),
        ],
        if (tier != AdultProtectionTier.off) ...[
          const SizedBox(height: 10),
          const RuleRemovalLockControls(compact: true),
        ],
      ],
    );
  }
}
