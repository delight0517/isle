import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/block/models/pending_rule_removal.dart';
import '../../../../core/block/models/premade_block_pack.dart';
import '../../../../core/block/premade_block_pack_service.dart';
import '../../../../core/block/rule_pending_removal_service.dart';
import '../../../../core/block/rule_removal_lock.dart';
import '../../../../core/block/schedule_premade_block_pack_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/rule_removal_lock_controls.dart';

/// 스케줄 편집 ④ 웹사이트·URL — 프리셋 팩 연결 (스케줄 활성 시에만 적용)
class SchedulePremadePackSection extends ConsumerStatefulWidget {
  const SchedulePremadePackSection({
    super.key,
    required this.scheduleId,
    required this.canEdit,
    this.onChanged,
  });

  final String scheduleId;
  final bool canEdit;
  final Future<void> Function({String? feedback})? onChanged;

  @override
  ConsumerState<SchedulePremadePackSection> createState() =>
      _SchedulePremadePackSectionState();
}

class _SchedulePremadePackSectionState extends ConsumerState<SchedulePremadePackSection> {
  List<PremadeBlockPack>? _packs;
  String? _busyPackId;
  String? _removingPackId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(rulePendingRemovalsProvider.notifier).refresh());
    });
  }

  Future<void> _load() async {
    final packs = await PremadeBlockPackService.loadNonAdultCatalog();
    if (!mounted) return;
    setState(() => _packs = packs);
  }

  String _pendingKey(String packId) =>
      SchedulePremadePackService.pendingRemovalKey(widget.scheduleId, packId);

  PendingRuleRemoval? _pendingFor(String packId) {
    for (final p in ref.watch(rulePendingRemovalsProvider)) {
      if (p.kind == PendingRuleRemovalKind.premadePack && p.key == _pendingKey(packId)) {
        return p;
      }
    }
    return null;
  }

  Future<void> _link(PremadeBlockPack pack) async {
    final linked = SchedulePremadePackService.isLinked(
      scheduleId: widget.scheduleId,
      packId: pack.packId,
    );
    final sensitive = pack.packId.contains('adult') || pack.packId.contains('illegal');
    if (sensitive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(linked ? '「${pack.displayName}」 동기화' : '「${pack.displayName}」 연결'),
          content: Text(
            linked
                ? '이 스케줄에 신규 규칙만 추가합니다.\n\n'
                    '스케줄이 켜져 있을 때만 Safari·피드·유튜브에 적용돼요.'
                : '${pack.entryCount}개 규칙을 이 스케줄에 연결합니다.\n\n'
                    '스케줄 시간대에만 차단 · 앱 전체 차단이 아니에요.\n'
                    '이미 있는 항목은 건너뜁니다.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(linked ? '동기화' : '연결'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyPackId = pack.packId);
    try {
      final result = await SchedulePremadePackService.linkPack(
        scheduleId: widget.scheduleId,
        packId: pack.packId,
      );
      if (!mounted) return;
      await widget.onChanged?.call(feedback: result.summary(pack.displayName));
      messenger.showSnackBar(
        SnackBar(content: Text(result.summary(pack.displayName))),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('프리셋 연결 실패: $e')));
    } finally {
      if (mounted) setState(() => _busyPackId = null);
    }
  }

  Future<void> _unlink(PremadeBlockPack pack) async {
    final pending = _pendingFor(pack.packId);
    if (pending != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('연결 해제 예약 취소'),
          content: Text(
            '「${pack.displayName}」 해제가 '
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
      if (ok == true && mounted) {
        await ref.read(rulePendingRemovalsProvider.notifier).cancel(
              PendingRuleRemovalKind.premadePack,
              _pendingKey(pack.packId),
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('연결 해제 예약을 취소했어요')),
        );
        setState(() {});
      }
      return;
    }

    final lockOn = RuleRemovalLock.lockEnabled;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('「${pack.displayName}」 연결 해제'),
        content: Text(
          lockOn
              ? '삭제 대기가 켜져 있어요.\n'
                  '${RuleRemovalLock.freezeMinutes}분 후 이 스케줄에서 팩 규칙이 자동 삭제됩니다.\n'
                  '그동안 스케줄이 켜지면 차단은 유지돼요.'
              : '이 스케줄에서 프리셋으로 추가된 규칙을 모두 삭제합니다.\n'
                  '직접 추가한 규칙은 남아요.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: lockOn
                ? FilledButton.styleFrom(backgroundColor: IsleColors.danger)
                : null,
            child: Text(lockOn ? '해제 예약' : '연결 해제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _removingPackId = pack.packId);
    try {
      final outcome = await ref.read(rulePendingRemovalsProvider.notifier).requestSchedulePremadePackRemove(
            scheduleId: widget.scheduleId,
            packId: pack.packId,
          );
      if (!mounted) return;
      switch (outcome.kind) {
        case RuleRemovalOutcomeKind.immediate:
          await widget.onChanged?.call(feedback: '「${pack.displayName}」 연결 해제됨');
          messenger.showSnackBar(
            SnackBar(content: Text('「${pack.displayName}」 연결 해제됨')),
          );
        case RuleRemovalOutcomeKind.scheduled:
        case RuleRemovalOutcomeKind.alreadyPending:
          final rem = outcome.remaining ?? Duration(minutes: RuleRemovalLock.freezeMinutes);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                '「${pack.displayName}」 — ${RulePendingRemovalService.formatRemaining(rem)}',
              ),
            ),
          );
      }
      setState(() {});
    } finally {
      if (mounted) setState(() => _removingPackId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packs = _packs;
    if (packs == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 18, color: IsleColors.ocean700),
            const SizedBox(width: 6),
            Text('프리셋 차단 팩', style: IsleText.subtitle()),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '게임·불법 웹툰 · 성인 보호는 보호 필터에서 설정',
          style: IsleText.badge(color: IsleColors.muted),
        ),
        const SizedBox(height: 10),
        const RuleRemovalLockControls(compact: true),
        const SizedBox(height: 10),
        ...packs.map((pack) => _PackCard(
              pack: pack,
              scheduleId: widget.scheduleId,
              canEdit: widget.canEdit,
              busy: _busyPackId == pack.packId,
              removing: _removingPackId == pack.packId,
              pending: _pendingFor(pack.packId),
              onLink: () => _link(pack),
              onUnlink: () => _unlink(pack),
            )),
      ],
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.scheduleId,
    required this.canEdit,
    required this.busy,
    required this.removing,
    required this.pending,
    required this.onLink,
    required this.onUnlink,
  });

  final PremadeBlockPack pack;
  final String scheduleId;
  final bool canEdit;
  final bool busy;
  final bool removing;
  final PendingRuleRemoval? pending;
  final VoidCallback onLink;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final linked = SchedulePremadePackService.isLinked(
      scheduleId: scheduleId,
      packId: pack.packId,
    );
    final update = SchedulePremadePackService.isUpdateAvailable(
      scheduleId: scheduleId,
      pack: pack,
    );
    final version = SchedulePremadePackService.linkedVersion(
      scheduleId: scheduleId,
      packId: pack.packId,
    );

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pack.displayName, style: IsleText.body()),
                      const SizedBox(height: 2),
                      Text(
                        pack.description,
                        style: IsleText.caption(color: IsleColors.muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (linked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: IsleColors.ocean100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      update ? '업데이트' : '연결됨',
                      style: IsleText.badge(
                        color: update ? IsleColors.gold500 : IsleColors.ocean700,
                      ),
                    ),
                  ),
              ],
            ),
            if (pending != null) ...[
              const SizedBox(height: 8),
              Text(
                '해제 예약 · ${RulePendingRemovalService.formatRemaining(pending!.remaining())}',
                style: IsleText.badge(color: IsleColors.danger),
              ),
            ],
            if (linked && version != null) ...[
              const SizedBox(height: 4),
              Text(
                '연결 버전 $version · 팩 ${pack.version}',
                style: IsleText.badge(color: IsleColors.muted),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (!linked || update)
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: canEdit && !busy && !removing ? onLink : null,
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(linked ? '동기화' : '연결'),
                    ),
                  ),
                if (linked) ...[
                  if (!linked || update) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: canEdit && !busy && !removing ? onUnlink : null,
                      child: removing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(pending != null ? '예약 취소' : '연결 해제'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
