import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/block/models/pending_rule_removal.dart';
import '../../../../core/block/models/premade_block_pack.dart';
import '../../../../core/block/premade_block_pack_registry.dart';
import '../../../../core/block/premade_block_pack_auto_sync_service.dart';
import '../../../../core/block/premade_block_pack_removal_service.dart';
import '../../../../core/block/premade_block_pack_service.dart';
import '../../../../core/block/rule_pending_removal_service.dart';
import '../../../../core/block/rule_removal_lock.dart';
import '../../../../core/safety/adult_protection_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/youtube/blocked_channel_store.dart';
import '../../../../core/youtube/blocked_url_store.dart';
import '../../../../core/youtube/content_filter_store.dart';
import '../../../feed/providers/feed_provider.dart';
import '../../../../shared/widgets/rule_removal_lock_controls.dart';
import 'premade_block_pack_browse_sheet.dart';

/// 4VPN PremadeBlockPacks — 원클릭 채널·키워드·URL·사이트 일괄 차단
class PremadeBlockPackSection extends ConsumerStatefulWidget {
  const PremadeBlockPackSection({super.key});

  @override
  ConsumerState<PremadeBlockPackSection> createState() =>
      _PremadeBlockPackSectionState();
}

class _PremadeBlockPackSectionState extends ConsumerState<PremadeBlockPackSection> {
  List<PremadeBlockPack>? _packs;
  String? _applyingId;
  String? _removingId;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(rulePendingRemovalsProvider.notifier).refresh());
      unawaited(_autoSyncApplied());
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      unawaited(_onTick());
    });
  }

  Future<void> _onTick() async {
    final pending = ref.read(rulePendingRemovalsProvider);
    final premade = pending.where((p) => p.kind == PendingRuleRemovalKind.premadePack).toList();
    if (premade.isEmpty) return;

    if (premade.any((p) => p.removeAtMs <= DateTime.now().millisecondsSinceEpoch)) {
      final removed = await ref.read(rulePendingRemovalsProvider.notifier).refresh();
      if (removed > 0 && mounted) {
        await ref.read(blockedChannelsProvider.notifier).reload();
        await ref.read(blockedKeywordsProvider.notifier).reload();
        await ref.read(blockedUrlsProvider.notifier).reload();
        await ref.read(feedProvider.notifier).removeBlockedFromFeed();
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    await PremadeBlockPackRegistry.ensureLoaded();
    final packs = await PremadeBlockPackService.loadCatalog();
    if (!mounted) return;
    setState(() => _packs = packs);
  }

  Future<void> _autoSyncApplied() async {
    await PremadeBlockPackAutoSyncService.syncAllApplied(silent: true);
    if (!mounted) return;
    await ref.read(blockedChannelsProvider.notifier).reload();
    await ref.read(blockedKeywordsProvider.notifier).reload();
    await ref.read(blockedUrlsProvider.notifier).reload();
    await ref.read(feedProvider.notifier).removeBlockedFromFeed();
    if (mounted) setState(() {});
  }

  bool _isPackLinkedInUi(PremadeBlockPack pack) {
    if (pack.packId == PremadeBlockPackService.adultCombinedPackId) {
      return AdultProtectionService.isFull &&
          PremadeBlockPackService.isPackApplied(pack.packId);
    }
    return PremadeBlockPackService.isPackApplied(pack.packId);
  }

  Future<void> _apply(PremadeBlockPack pack) async {
    if (_isPackLinkedInUi(pack)) return;

    final isAdult = pack.packId == PremadeBlockPackService.adultCombinedPackId;
    final sensitive = isAdult || PremadeBlockPackRegistry.isSensitivePack(pack.packId);
    if (sensitive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('「${pack.displayName}」 적용'),
          content: Text(
            '${pack.entryCount}개 규칙을 한 번에 추가합니다.\n\n'
            '· YouTube 채널 / 검색·피드 키워드 / URL\n'
            '· Safari 사이트(해당 팩에 포함 시)\n'
            '${isAdult ? '· 성인 보호가 「강화」로 전환돼요\n' : ''}'
            '\n이후 앱 업데이트·복귀 시 신규 항목은 자동 반영돼요.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('프리셋 차단하기'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _applyingId = pack.packId);
    try {
      if (isAdult) {
        final tierResult = await AdultProtectionService.ensureFullPackApplied();
        if (!mounted) return;
        if (tierResult.packApplied) {
          await ref.read(blockedChannelsProvider.notifier).reload();
          await ref.read(blockedKeywordsProvider.notifier).reload();
          await ref.read(blockedUrlsProvider.notifier).reload();
          await ref.read(feedProvider.notifier).removeBlockedFromFeed();
          await IsleUserDefaults.setPremadePackCardExpanded(pack.packId, true);
        }
        if (tierResult.message != null) {
          messenger.showSnackBar(SnackBar(content: Text(tierResult.message!)));
        }
      } else {
        final result = await PremadeBlockPackService.applyPack(pack.packId);
        if (!mounted) return;
        await ref.read(blockedChannelsProvider.notifier).reload();
        await ref.read(blockedKeywordsProvider.notifier).reload();
        await ref.read(blockedUrlsProvider.notifier).reload();
        await ref.read(feedProvider.notifier).removeBlockedFromFeed();
        messenger.showSnackBar(
          SnackBar(content: Text(result.summary(pack.displayName))),
        );
        await IsleUserDefaults.setPremadePackCardExpanded(pack.packId, true);
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('팩 적용 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _applyingId = null);
    }
  }

  Future<void> _remove(PremadeBlockPack pack) async {
    final freezeMin = RuleRemovalLock.freezeMinutes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('「${pack.displayName}」 연결 해제'),
        content: Text(
          '이 팩으로 추가된 규칙만 제거합니다.\n\n'
          '$freezeMin분 후 자동으로 연결 해제돼요. '
          '앱을 꺼도 타이머는 계속 진행되고, 시간이 되면 자동 해제됩니다.\n'
          '그동안 차단은 그대로 유지돼요.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: IsleColors.danger),
            child: Text('$freezeMin분 후 해제 예약'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _removingId = pack.packId);
    try {
      final outcome = await ref
          .read(rulePendingRemovalsProvider.notifier)
          .requestPremadePackRemove(pack.packId);
      if (!mounted) return;
      showRuleRemovalOutcomeSnackBar(
        context,
        outcome,
        freezeMinutes: freezeMin,
        itemLabel: RulePendingRemovalService.packRemovalLabel(pack.packId),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('팩 해제 실패: $e')));
    } finally {
      if (mounted) setState(() => _removingId = null);
    }
  }

  Future<void> _cancelPending(PremadeBlockPack pack) async {
    final pending = _pendingForPack(pack.packId);
    if (pending == null) return;
    await ref.read(rulePendingRemovalsProvider.notifier).cancel(
          PendingRuleRemovalKind.premadePack,
          PremadeBlockPackRemovalService.resolvePackId(pack.packId),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('연결 해제 예약을 취소했어요')),
    );
    setState(() {});
  }

  PendingRuleRemoval? _pendingForPack(String packId) {
    final pending = ref.watch(rulePendingRemovalsProvider);
    final resolved = PremadeBlockPackRemovalService.resolvePackId(packId);
    for (final p in pending) {
      if (p.kind == PendingRuleRemovalKind.premadePack && p.key == resolved) {
        return p;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final packs = _packs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('프리셋 차단 팩', style: IsleText.subtitle()),
        const SizedBox(height: 6),
        Text(
          'manifest 4종 전부 — 성인·도박·게임·불법 웹툰 (4VPN 동일). '
          '적용 후 신규 항목 자동 동기화 · 목록 검색·개별 제외 · '
          '팩 해제 ${RuleRemovalLock.freezeMinutes}분 타이머 (앱 꺼져도 진행). '
          '카드 탭으로 접기·펼치기 (기억됨).',
          style: IsleText.caption(color: IsleColors.muted),
        ),
        const SizedBox(height: 12),
        if (packs == null)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (packs.isEmpty)
          Text('팩을 불러오지 못했어요', style: IsleText.body(color: IsleColors.muted))
        else
          ...packs.map((p) {
            final pending = _pendingForPack(p.packId);
            final applied = _isPackLinkedInUi(p);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PackCard(
                pack: p,
                applying: _applyingId == p.packId,
                removing: _removingId == p.packId,
                applied: applied,
                linkedVersion: PremadeBlockPackService.linkedPackVersion(p.packId),
                pendingRemoval: pending,
                onApply: () => _apply(p),
                onBrowse: () => showPremadeBlockPackBrowseSheet(context, pack: p),
                onRemove: () => _remove(p),
                onCancelPending: pending != null ? () => _cancelPending(p) : null,
              ),
            );
          }),
      ],
    );
  }
}

String _packPendingLabel(Duration d) {
  final m = d.inMinutes;
  if (m > 0) return '$m분 후 연결 해제';
  final s = d.inSeconds.remainder(60);
  return s > 0 ? '$s초 후 연결 해제' : '곧 연결 해제';
}

class _PackCard extends StatefulWidget {
  const _PackCard({
    required this.pack,
    required this.applying,
    required this.removing,
    required this.applied,
    required this.linkedVersion,
    required this.pendingRemoval,
    required this.onApply,
    required this.onBrowse,
    required this.onRemove,
    this.onCancelPending,
  });

  final PremadeBlockPack pack;
  final bool applying;
  final bool removing;
  final bool applied;
  final String? linkedVersion;
  final PendingRuleRemoval? pendingRemoval;
  final VoidCallback onApply;
  final VoidCallback onBrowse;
  final VoidCallback onRemove;
  final VoidCallback? onCancelPending;

  @override
  State<_PackCard> createState() => _PackCardState();
}

class _PackCardState extends State<_PackCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = IsleUserDefaults.isPremadePackCardExpanded(widget.pack.packId);
  }

  @override
  void didUpdateWidget(covariant _PackCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.applied && !oldWidget.applied && !_expanded) {
      _expanded = true;
      unawaited(IsleUserDefaults.setPremadePackCardExpanded(widget.pack.packId, true));
    }
  }

  Future<void> _toggleExpanded() async {
    final next = !_expanded;
    await IsleUserDefaults.setPremadePackCardExpanded(widget.pack.packId, next);
    if (!mounted) return;
    setState(() => _expanded = next);
  }

  PremadeBlockPack get pack => widget.pack;

  IconData get _icon {
    final def = PremadeBlockPackRegistry.definitionFor(pack.packId);
    if (def != null) return PremadeBlockPackRegistry.iconFor(def);
    if (pack.packId.contains('gambl')) return Icons.casino_outlined;
    if (pack.packId.contains('illegal')) return Icons.gavel_outlined;
    if (pack.packId.contains('gaming')) return Icons.sports_esports_outlined;
    return Icons.shield_outlined;
  }

  Color get _accent {
    final def = PremadeBlockPackRegistry.definitionFor(pack.packId);
    if (def != null) return PremadeBlockPackRegistry.accentFor(def);
    if (pack.packId.contains('adult')) return IsleColors.danger;
    if (pack.packId.contains('gambl')) return const Color(0xFF7C3AED);
    if (pack.packId.contains('illegal')) return const Color(0xFFB45309);
    if (pack.packId.contains('gaming')) return IsleColors.ocean700;
    return IsleColors.ocean500;
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.pendingRemoval;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _toggleExpanded,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icon, color: _accent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pack.displayName,
                                  style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (pending != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _packPendingLabel(pending.remaining()),
                                    style: IsleText.caption(color: Colors.orange.shade900),
                                  ),
                                )
                              else if (widget.applied)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: IsleColors.ocean100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '연결됨 · 자동 동기화',
                                    style: IsleText.caption(color: IsleColors.ocean700),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.linkedVersion != null
                                ? '${pack.entryCount}개 · 팩 v${pack.version} · 연결 v${widget.linkedVersion}'
                                : '${pack.entryCount}개 · ${pack.description}',
                            style: IsleText.caption(color: IsleColors.muted),
                            maxLines: _expanded ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: IsleColors.muted,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              if (!widget.applied && pending == null) ...[
                SizedBox(
                  width: double.infinity,
                  height: IsleSize.minTouchTarget,
                  child: FilledButton.icon(
                    onPressed: widget.applying || widget.removing ? null : widget.onApply,
                    icon: widget.applying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.shield_outlined, size: 20),
                    label: Text(widget.applying ? '적용 중…' : '프리셋 차단하기'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: IsleSize.minTouchTarget,
                  child: OutlinedButton.icon(
                    onPressed: widget.onBrowse,
                    icon: const Icon(Icons.list_alt_rounded, size: 20),
                    label: const Text('목록 보기 · 검색'),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: IsleSize.minTouchTarget,
                  child: OutlinedButton.icon(
                    onPressed: widget.onBrowse,
                    icon: const Icon(Icons.list_alt_rounded, size: 20),
                    label: const Text('목록 보기 · 검색'),
                  ),
                ),
                if (pending == null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: IsleSize.minTouchTarget,
                    child: OutlinedButton.icon(
                      onPressed: widget.applying || widget.removing ? null : widget.onRemove,
                      icon: widget.removing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link_off_outlined, size: 20),
                      label: Text(widget.removing ? '예약 중…' : '팩 연결 해제'),
                    ),
                  ),
                ] else if (widget.onCancelPending != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: IsleSize.minTouchTarget,
                    child: TextButton.icon(
                      onPressed: widget.onCancelPending,
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('해제 예약 취소'),
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}
