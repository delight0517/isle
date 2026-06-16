import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/isle_app_log_service.dart';
import 'models/pending_rule_removal.dart';
import 'rule_pending_removal_store.dart';
import 'rule_removal_lock.dart';

enum RuleRemovalOutcomeKind { immediate, scheduled, alreadyPending }

class RuleRemovalOutcome {
  const RuleRemovalOutcome._(this.kind, {this.remaining});

  final RuleRemovalOutcomeKind kind;
  final Duration? remaining;

  factory RuleRemovalOutcome.immediate() =>
      const RuleRemovalOutcome._(RuleRemovalOutcomeKind.immediate);

  factory RuleRemovalOutcome.scheduled(Duration remaining) =>
      RuleRemovalOutcome._(RuleRemovalOutcomeKind.scheduled, remaining: remaining);

  factory RuleRemovalOutcome.alreadyPending(Duration remaining) =>
      RuleRemovalOutcome._(RuleRemovalOutcomeKind.alreadyPending, remaining: remaining);
}

typedef RuleKeywordRemover = Future<void> Function(String key);
typedef RuleUrlRemover = Future<void> Function(String canonicalUrl);
typedef RuleRemovalExportHook = void Function();

/// 키워드·URL — 잠금 ON이면 N분 후 자동 삭제 (그동안 차단 유지)
class RulePendingRemovalService {
  RulePendingRemovalService._();

  static RuleKeywordRemover? _removeKeyword;
  static RuleUrlRemover? _removeUrl;
  static RuleRemovalExportHook? _afterRemoval;

  static void registerHandlers({
    required RuleKeywordRemover removeKeyword,
    required RuleUrlRemover removeUrl,
    RuleRemovalExportHook? afterRemoval,
  }) {
    _removeKeyword = removeKeyword;
    _removeUrl = removeUrl;
    _afterRemoval = afterRemoval;
  }

  static Future<int> processDue() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final pending = RulePendingRemovalStore.loadAll();
    if (pending.isEmpty) return 0;

    var removed = 0;
    final keep = <PendingRuleRemoval>[];
    for (final p in pending) {
      if (p.removeAtMs > now) {
        keep.add(p);
        continue;
      }
      await _executeRemoval(p);
      removed++;
    }
    if (removed > 0) {
      await RulePendingRemovalStore.saveAll(keep);
      IsleAppLogService.log('Rule pending removal: $removed item(s) auto-removed');
      _afterRemoval?.call();
    } else if (keep.length != pending.length) {
      await RulePendingRemovalStore.saveAll(keep);
    }
    return removed;
  }

  static Future<void> _executeRemoval(PendingRuleRemoval p) async {
    switch (p.kind) {
      case PendingRuleRemovalKind.keyword:
        await _removeKeyword?.call(p.key);
      case PendingRuleRemovalKind.blockedUrl:
        await _removeUrl?.call(p.key);
    }
  }

  static Future<RuleRemovalOutcome> requestKeywordRemove(String keyword) async {
    await processDue();
    final key = keyword.trim().toLowerCase();
    if (key.isEmpty) return RuleRemovalOutcome.immediate();

    if (!RuleRemovalLock.lockEnabled) {
      await _removeKeyword?.call(key);
      await cancel(PendingRuleRemovalKind.keyword, key);
      _afterRemoval?.call();
      return RuleRemovalOutcome.immediate();
    }

    final existing = RulePendingRemovalStore.find(PendingRuleRemovalKind.keyword, key);
    if (existing != null) {
      return RuleRemovalOutcome.alreadyPending(existing.remaining());
    }

    final delay = Duration(minutes: RuleRemovalLock.freezeMinutes);
    final now = DateTime.now();
    final pending = PendingRuleRemoval(
      kind: PendingRuleRemovalKind.keyword,
      key: key,
      scheduledAtMs: now.millisecondsSinceEpoch,
      removeAtMs: now.add(delay).millisecondsSinceEpoch,
    );
    final list = RulePendingRemovalStore.loadAll()
      ..removeWhere((p) => p.kind == PendingRuleRemovalKind.keyword && p.key == key)
      ..add(pending);
    await RulePendingRemovalStore.saveAll(list);
    return RuleRemovalOutcome.scheduled(delay);
  }

  static Future<RuleRemovalOutcome> requestUrlRemove(String rawUrl) async {
    await processDue();
    final key = rawUrl.trim();
    if (key.isEmpty) return RuleRemovalOutcome.immediate();

    if (!RuleRemovalLock.lockEnabled) {
      await _removeUrl?.call(key);
      await cancel(PendingRuleRemovalKind.blockedUrl, key);
      _afterRemoval?.call();
      return RuleRemovalOutcome.immediate();
    }

    final existing = RulePendingRemovalStore.find(PendingRuleRemovalKind.blockedUrl, key);
    if (existing != null) {
      return RuleRemovalOutcome.alreadyPending(existing.remaining());
    }

    final delay = Duration(minutes: RuleRemovalLock.freezeMinutes);
    final now = DateTime.now();
    final pending = PendingRuleRemoval(
      kind: PendingRuleRemovalKind.blockedUrl,
      key: key,
      scheduledAtMs: now.millisecondsSinceEpoch,
      removeAtMs: now.add(delay).millisecondsSinceEpoch,
    );
    final list = RulePendingRemovalStore.loadAll()
      ..removeWhere((p) => p.kind == PendingRuleRemovalKind.blockedUrl && p.key == key)
      ..add(pending);
    await RulePendingRemovalStore.saveAll(list);
    return RuleRemovalOutcome.scheduled(delay);
  }

  static Future<void> cancel(PendingRuleRemovalKind kind, String key) =>
      RulePendingRemovalStore.cancelKind(kind, key);

  static PendingRuleRemoval? pendingKeyword(String keyword) {
    return RulePendingRemovalStore.find(
      PendingRuleRemovalKind.keyword,
      keyword.trim().toLowerCase(),
    );
  }

  static PendingRuleRemoval? pendingUrl(String canonicalUrl) {
    return RulePendingRemovalStore.find(
      PendingRuleRemovalKind.blockedUrl,
      canonicalUrl.trim(),
    );
  }

  static String formatRemaining(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '$h시간 $m분 후 삭제';
    if (m > 0) return '$m분 후 자동 삭제';
    final s = d.inSeconds.remainder(60);
    return s > 0 ? '$s초 후 자동 삭제' : '곧 삭제';
  }
}

final rulePendingRemovalsProvider =
    StateNotifierProvider<RulePendingRemovalsNotifier, List<PendingRuleRemoval>>(
  (ref) => RulePendingRemovalsNotifier(),
);

class RulePendingRemovalsNotifier extends StateNotifier<List<PendingRuleRemoval>> {
  RulePendingRemovalsNotifier() : super(RulePendingRemovalStore.loadAll());

  Future<int> refresh() async {
    final removed = await RulePendingRemovalService.processDue();
    state = RulePendingRemovalStore.loadAll();
    return removed;
  }

  Future<RuleRemovalOutcome> requestKeywordRemove(String keyword) async {
    final outcome = await RulePendingRemovalService.requestKeywordRemove(keyword);
    state = RulePendingRemovalStore.loadAll();
    return outcome;
  }

  Future<RuleRemovalOutcome> requestUrlRemove(String canonicalUrl) async {
    final outcome = await RulePendingRemovalService.requestUrlRemove(canonicalUrl);
    state = RulePendingRemovalStore.loadAll();
    return outcome;
  }

  Future<void> cancel(PendingRuleRemovalKind kind, String key) async {
    await RulePendingRemovalService.cancel(kind, key);
    state = RulePendingRemovalStore.loadAll();
  }
}
