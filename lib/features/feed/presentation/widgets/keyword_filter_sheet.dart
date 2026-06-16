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
import '../../../../core/youtube/content_filter_store.dart';
import '../../providers/feed_provider.dart';

/// 제목·채널명에 포함된 키워드는 피드·유튜브 WebView에서 숨김
Future<void> showKeywordFilterSheet(BuildContext context) {
  return showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => const _KeywordFilterBody(),
  );
}

class _KeywordFilterBody extends ConsumerStatefulWidget {
  const _KeywordFilterBody();

  @override
  ConsumerState<_KeywordFilterBody> createState() => _KeywordFilterBodyState();
}

class _KeywordFilterBodyState extends ConsumerState<_KeywordFilterBody> {
  final _addCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();
  Timer? _refreshWake;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshPending());
    });
    _inputFocus.addListener(_scrollInputIntoView);
  }

  @override
  void dispose() {
    _refreshWake?.cancel();
    _inputFocus.removeListener(_scrollInputIntoView);
    _inputFocus.dispose();
    _scrollCtrl.dispose();
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshPending() async {
    final removed = await ref.read(rulePendingRemovalsProvider.notifier).refresh();
    if (removed > 0) {
      await ref.read(blockedKeywordsProvider.notifier).reload();
      ref.invalidate(feedProvider);
    }
    if (!mounted) return;
    setState(_scheduleRefreshWake);
  }

  void _scheduleRefreshWake() {
    _refreshWake?.cancel();
    final pending = ref.read(rulePendingRemovalsProvider);
    final keywordPending = pending.where((p) => p.kind == PendingRuleRemovalKind.keyword);
    if (keywordPending.isEmpty) return;

    var nextSec = 30;
    for (final p in keywordPending) {
      final sec = p.remaining().inSeconds.clamp(1, 3600);
      if (sec < nextSec) nextSec = sec;
    }
    _refreshWake = Timer(Duration(seconds: nextSec), () {
      if (!mounted) return;
      unawaited(_refreshPending());
    });
  }

  void _scrollInputIntoView() {
    if (!_inputFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _removeKeyword(String k) async {
    final outcome = await RulePendingRemovalService.requestKeywordRemove(k);
    final removed = await ref.read(rulePendingRemovalsProvider.notifier).refresh();
    await ref.read(blockedKeywordsProvider.notifier).reload();
    if (!mounted) return;
    showRuleRemovalOutcomeSnackBar(
      context,
      outcome,
      freezeMinutes: RuleRemovalLock.freezeMinutes,
      itemLabel: '키워드',
    );
    if (outcome.kind == RuleRemovalOutcomeKind.immediate || removed > 0) {
      ref.invalidate(feedProvider);
    }
    setState(_scheduleRefreshWake);
  }

  Future<void> _cancelPending(String k) async {
    await ref.read(rulePendingRemovalsProvider.notifier).cancel(
          PendingRuleRemovalKind.keyword,
          k,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('삭제 예약을 취소했어요 — 차단은 계속 유지')),
    );
    setState(_scheduleRefreshWake);
  }

  @override
  Widget build(BuildContext context) {
    final keywords = ref.watch(blockedKeywordsProvider);
    ref.watch(rulePendingRemovalsProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('숨길 키워드', style: IsleText.subtitle()),
              const SizedBox(height: 8),
              Text(
                '적용 범위: Isle 피드 + YouTube 검색·피드 + Safari(구글 검색·Discover).\n'
                'Safari(⋮) → 「이 URL 차단」·「숨길 키워드」.',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addCtrl,
                      focusNode: _inputFocus,
                      decoration: const InputDecoration(
                        labelText: '키워드 추가',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _add, child: const Text('추가')),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SuggestionChip('연예', onTap: () => _quickAdd('연예')),
                  _SuggestionChip('쇼츠', onTap: () => _quickAdd('쇼츠')),
                  _SuggestionChip('가십', onTap: () => _quickAdd('가십')),
                  _SuggestionChip('자극', onTap: () => _quickAdd('자극')),
                ],
              ),
              const SizedBox(height: 12),
              if (keywords.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      '등록된 키워드 없음',
                      style: IsleText.caption(color: IsleColors.muted),
                    ),
                  ),
                )
              else
                ...keywords.map((k) {
                  final pending = RulePendingRemovalService.pendingKeyword(k);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: pending != null
                        ? Icon(Icons.hourglass_bottom, size: 18, color: Colors.orange.shade800)
                        : null,
                    title: Text(k, style: IsleText.body()),
                    subtitle: pending != null
                        ? Text(
                            RulePendingRemovalService.formatRemaining(pending.remaining()),
                            style: IsleText.caption(color: Colors.orange.shade900),
                          )
                        : null,
                    trailing: pending != null
                        ? TextButton(
                            onPressed: () => unawaited(_cancelPending(k)),
                            child: const Text('취소'),
                          )
                        : IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => unawaited(_removeKeyword(k)),
                          ),
                  );
                }),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                '키워드 삭제할 때',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              const SizedBox(height: 8),
              const RuleRemovalLockControls(compact: true, perItemDelay: true),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _add() async {
    final t = _addCtrl.text.trim();
    if (t.isEmpty) return;
    await ref.read(blockedKeywordsProvider.notifier).add(t);
    await ref.read(rulePendingRemovalsProvider.notifier).refresh();
    _addCtrl.clear();
    ref.invalidate(feedProvider);
  }

  Future<void> _quickAdd(String keyword) async {
    await ref.read(blockedKeywordsProvider.notifier).add(keyword);
    await ref.read(rulePendingRemovalsProvider.notifier).refresh();
    ref.invalidate(feedProvider);
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      onPressed: onTap,
      backgroundColor: IsleColors.ocean100,
      side: BorderSide.none,
    );
  }
}
