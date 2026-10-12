import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/usage_budget/usage_budget_engine.dart';
import 'package:isle/core/usage_budget/usage_budget_models.dart';

void main() {
  test('refill is capped by remaining daily budget', () {
    final start = DateTime(2026, 7, 1, 8);
    final policy = UsageBudgetPolicy(
      target: UsageBudgetTarget.youtube,
      enabled: true,
      dailyCapMinutes: 60,
      burstCapMinutes: 20,
      refillAmountMinutes: 20,
      refillIntervalMinutes: 60,
      cooldownMinutes: 60,
      updatedAt: start,
    );

    var ledger = UsageBudgetEngine.initialLedger(policy, start);
    ledger = UsageBudgetEngine.addUsage(policy, ledger, 8 * 60, start);

    final afterFirstRefill = start.add(const Duration(hours: 1));
    ledger =
        UsageBudgetEngine.addUsage(policy, ledger, 20 * 60, afterFirstRefill);

    final afterSecondRefill = afterFirstRefill.add(const Duration(hours: 1));
    ledger =
        UsageBudgetEngine.addUsage(policy, ledger, 20 * 60, afterSecondRefill);

    final snap = UsageBudgetEngine.snapshot(
      policy,
      ledger,
      afterSecondRefill.add(const Duration(hours: 1)),
    );

    expect(snap.ledger.usedSecondsToday, 48 * 60);
    expect(snap.availableSeconds, 12 * 60);
    expect(snap.dailyRemainingSeconds, 12 * 60);
  });

  test('using a full burst starts cooldown', () {
    final start = DateTime(2026, 7, 1, 8);
    final policy = UsageBudgetPolicy(
      target: UsageBudgetTarget.youtube,
      enabled: true,
      dailyCapMinutes: 60,
      burstCapMinutes: 20,
      refillAmountMinutes: 20,
      refillIntervalMinutes: 60,
      cooldownMinutes: 60,
      updatedAt: start,
    );

    final ledger = UsageBudgetEngine.addUsage(
      policy,
      UsageBudgetEngine.initialLedger(policy, start),
      20 * 60,
      start,
    );

    final snap = UsageBudgetEngine.snapshot(
      policy,
      ledger,
      start.add(const Duration(minutes: 30)),
    );

    expect(snap.isLocked, isTrue);
    expect(snap.availableSeconds, 0);
  });
}
