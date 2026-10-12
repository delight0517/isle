import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'usage_budget_engine.dart';
import 'usage_budget_models.dart';

class UsageBudgetStore {
  UsageBudgetStore._();

  static const _boxName = 'isle_usage_budget';
  static const _policyPrefix = 'policy_';
  static const _ledgerPrefix = 'ledger_';
  static const _pendingPrefix = 'pending_policy_';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('UsageBudgetStore not open');
    return b;
  }

  static String _policyKey(String target) => '$_policyPrefix$target';
  static String _ledgerKey(String target) => '$_ledgerPrefix$target';
  static String _pendingKey(String target) => '$_pendingPrefix$target';

  /// 나눠쓰기(usage budget)가 설정된(활성 여부 무관) 모든 target — "오늘 블락
  /// 뭐가 켜져있어?" 같은 전체 조회에서 특정 앱을 안 물어봐도 전부 훑을 때 씀.
  static List<String> configuredTargets() {
    return box.keys
        .whereType<String>()
        .where((k) => k.startsWith(_policyPrefix))
        .map((k) => k.substring(_policyPrefix.length))
        .toList();
  }

  static UsageBudgetPolicy? policyFor(String target) {
    final raw = box.get(_policyKey(target));
    if (raw == null || raw.isEmpty) return null;
    try {
      return UsageBudgetPolicy.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static bool isEnabled(String target) => policyFor(target)?.enabled ?? false;

  static UsageBudgetLedger ledgerFor(
    UsageBudgetPolicy policy, {
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final raw = box.get(_ledgerKey(policy.target));
    if (raw == null || raw.isEmpty)
      return UsageBudgetEngine.initialLedger(policy, at);
    try {
      return UsageBudgetLedger.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return UsageBudgetEngine.initialLedger(policy, at);
    }
  }

  static Future<void> savePolicy(UsageBudgetPolicy policy) async {
    final normalized = policy.copyWith(
      dailyCapMinutes: policy.dailyCapMinutes.clamp(5, 720),
      burstCapMinutes: policy.burstCapMinutes.clamp(1, 240),
      refillAmountMinutes: policy.refillAmountMinutes.clamp(1, 240),
      refillIntervalMinutes: policy.refillIntervalMinutes.clamp(5, 720),
      cooldownMinutes: policy.cooldownMinutes.clamp(1, 720),
      updatedAt: DateTime.now(),
    );
    await box.put(_policyKey(policy.target), jsonEncode(normalized.toJson()));

    final ledger = ledgerFor(normalized);
    final next =
        UsageBudgetEngine.normalize(normalized, ledger, DateTime.now());
    await saveLedger(normalized.target, next);
  }

  static UsageBudgetPendingPolicy? pendingPolicyFor(String target) {
    final raw = box.get(_pendingKey(target));
    if (raw == null || raw.isEmpty) return null;
    try {
      return UsageBudgetPendingPolicy.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static List<UsageBudgetPendingPolicy> pendingPolicies() {
    final out = <UsageBudgetPendingPolicy>[];
    for (final key in box.keys) {
      if (key is! String || !key.startsWith(_pendingPrefix)) continue;
      final target = key.substring(_pendingPrefix.length);
      final pending = pendingPolicyFor(target);
      if (pending != null) out.add(pending);
    }
    return out;
  }

  static Future<void> savePendingPolicy(
    UsageBudgetPendingPolicy pending,
  ) async {
    await box.put(_pendingKey(pending.target), jsonEncode(pending.toJson()));
  }

  static Future<void> clearPendingPolicy(String target) async {
    await box.delete(_pendingKey(target));
  }

  static Future<void> saveLedger(
    String target,
    UsageBudgetLedger ledger,
  ) async {
    await box.put(_ledgerKey(target), jsonEncode(ledger.toJson()));
  }

  static Future<void> setEnabled(String target, bool enabled) async {
    final current = policyFor(target);
    if (current == null) return;
    await savePolicy(current.copyWith(enabled: enabled));
  }

  static Future<void> clearPolicy(String target) async {
    await box.delete(_policyKey(target));
    await box.delete(_ledgerKey(target));
  }

  static UsageBudgetSnapshot? snapshot(
    String target, {
    DateTime? now,
  }) {
    final policy = policyFor(target);
    if (policy == null || !policy.enabled) return null;
    final at = now ?? DateTime.now();
    final ledger = ledgerFor(policy, now: at);
    final snap = UsageBudgetEngine.snapshot(policy, ledger, at);
    if (snap.ledger != ledger) {
      // Fire-and-forget would hide a sync write. This method is often called in build/tick,
      // so callers that need persistence should call [refresh].
    }
    return snap;
  }

  static Future<UsageBudgetSnapshot?> refresh(
    String target, {
    DateTime? now,
  }) async {
    final policy = policyFor(target);
    if (policy == null || !policy.enabled) return null;
    final at = now ?? DateTime.now();
    final ledger = ledgerFor(policy, now: at);
    final snap = UsageBudgetEngine.snapshot(policy, ledger, at);
    await saveLedger(target, snap.ledger);
    return snap;
  }

  static bool isLimitReached(String target) {
    final snap = snapshot(target);
    return snap?.isLocked ?? false;
  }

  static bool shouldCount(String target) {
    final snap = snapshot(target);
    return snap?.canCount ?? false;
  }

  static void addSeconds(String target, int seconds) {
    final policy = policyFor(target);
    if (policy == null || !policy.enabled || seconds <= 0) return;
    final now = DateTime.now();
    final ledger = ledgerFor(policy, now: now);
    final next = UsageBudgetEngine.addUsage(policy, ledger, seconds, now);
    box.put(_ledgerKey(target), jsonEncode(next.toJson()));
  }

  static String formatStatusLine(String target) {
    final policy = policyFor(target);
    if (policy == null || !policy.enabled) return '충전식 한도 꺼짐';
    final snap = snapshot(target);
    if (snap == null) return '충전식 한도 꺼짐';
    final used = snap.ledger.usedSecondsToday ~/ 60;
    final daily = policy.dailyCapMinutes;
    final available = snap.availableSeconds ~/ 60;
    final dailyRemain = snap.dailyRemainingSeconds ~/ 60;
    if (snap.isLocked) {
      final until = snap.lockedUntil;
      if (until != null) {
        final left = until.difference(DateTime.now());
        final wait = left.inMinutes.clamp(0, 24 * 60);
        return '하루 $daily분 · ${policy.burstCapMinutes}분씩 · ${wait}분 후 다시';
      }
      return '하루 $daily분 · 지금 잠김';
    }
    return '하루 $daily분 중 ${used}분 사용 · 지금 ${available}분 가능 · 오늘 ${dailyRemain}분 남음';
  }
}
