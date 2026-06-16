import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/isle_sheet.dart';
import '../../../../shared/widgets/rule_removal_lock_controls.dart';
import '../../../../core/block/models/pending_rule_removal.dart';
import '../../../../core/block/rule_pending_removal_service.dart';
import '../../../../core/block/rule_removal_lock.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/youtube/blocked_url_store.dart';

Future<void> showBlockedUrlSheet(BuildContext context) {
  return showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => const _BlockedUrlBody(),
  );
}

class _BlockedUrlBody extends ConsumerStatefulWidget {
  const _BlockedUrlBody();

  @override
  ConsumerState<_BlockedUrlBody> createState() => _BlockedUrlBodyState();
}

class _BlockedUrlBodyState extends ConsumerState<_BlockedUrlBody> {
  Timer? _refreshWake;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshPending());
    });
  }

  @override
  void dispose() {
    _refreshWake?.cancel();
    super.dispose();
  }

  Future<void> _refreshPending() async {
    final removed = await ref.read(rulePendingRemovalsProvider.notifier).refresh();
    if (removed > 0) {
      await ref.read(blockedUrlsProvider.notifier).reload();
    }
    if (!mounted) return;
    setState(_scheduleRefreshWake);
  }

  void _scheduleRefreshWake() {
    _refreshWake?.cancel();
    final pending = ref.read(rulePendingRemovalsProvider);
    final urlPending = pending.where((p) => p.kind == PendingRuleRemovalKind.blockedUrl);
    if (urlPending.isEmpty) return;

    var nextSec = 30;
    for (final p in urlPending) {
      final sec = p.remaining().inSeconds.clamp(1, 3600);
      if (sec < nextSec) nextSec = sec;
    }
    _refreshWake = Timer(Duration(seconds: nextSec), () {
      if (!mounted) return;
      unawaited(_refreshPending());
    });
  }

  Future<void> _removeUrl(String canonicalUrl) async {
    final outcome = await RulePendingRemovalService.requestUrlRemove(canonicalUrl);
    await ref.read(rulePendingRemovalsProvider.notifier).refresh();
    await ref.read(blockedUrlsProvider.notifier).reload();
    if (!mounted) return;
    showRuleRemovalOutcomeSnackBar(
      context,
      outcome,
      freezeMinutes: RuleRemovalLock.freezeMinutes,
      itemLabel: 'URL',
    );
    setState(_scheduleRefreshWake);
  }

  Future<void> _cancelPending(String canonicalUrl) async {
    await ref.read(rulePendingRemovalsProvider.notifier).cancel(
          PendingRuleRemovalKind.blockedUrl,
          canonicalUrl,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('삭제 예약을 취소했어요 — 차단은 계속 유지')),
    );
    setState(_scheduleRefreshWake);
  }

  @override
  Widget build(BuildContext context) {
    final urls = ref.watch(blockedUrlsProvider);
    ref.watch(rulePendingRemovalsProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('차단 URL', style: IsleText.subtitle()),
            const SizedBox(height: 8),
            Text(
              'YouTube 검색·피드·구글 검색·Discover에서 해당 링크 카드를 숨깁니다.\n'
              'Safari(⋮) → 「이 URL 차단」으로 추가.',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            const SizedBox(height: 12),
            const RuleRemovalLockControls(compact: true, perItemDelay: true),
            const SizedBox(height: 12),
            if (urls.isEmpty)
              Text('아직 없어요', style: IsleText.body(color: IsleColors.muted))
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: urls.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final u = urls[i];
                    final pending =
                        RulePendingRemovalService.pendingUrl(u.canonicalUrl);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: pending != null
                          ? Icon(Icons.hourglass_bottom,
                              size: 18, color: Colors.orange.shade800)
                          : null,
                      title: Text(
                        u.label ?? u.canonicalUrl,
                        style: IsleText.body(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: pending != null
                          ? Text(
                              RulePendingRemovalService.formatRemaining(
                                pending.remaining(),
                              ),
                              style: IsleText.caption(color: Colors.orange.shade900),
                            )
                          : u.label != null
                              ? Text(
                                  u.canonicalUrl,
                                  style: IsleText.caption(color: IsleColors.muted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                      trailing: pending != null
                          ? TextButton(
                              onPressed: () => unawaited(_cancelPending(u.canonicalUrl)),
                              child: const Text('취소'),
                            )
                          : IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => unawaited(_removeUrl(u.canonicalUrl)),
                            ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
