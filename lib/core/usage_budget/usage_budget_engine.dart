import '../library/usage_day.dart';
import 'usage_budget_models.dart';

class UsageBudgetEngine {
  const UsageBudgetEngine._();

  static String dayKey(DateTime at) => UsageDay.key(at);

  static DateTime nextDay(DateTime at) => UsageDay.nextMidnight(at);

  static UsageBudgetLedger initialLedger(
      UsageBudgetPolicy policy, DateTime now) {
    return UsageBudgetLedger(
      dayKey: dayKey(now),
      usedSecondsToday: 0,
      tokenSeconds: policy.burstCapSeconds.clamp(0, policy.dailyCapSeconds),
      lastRefillAt: now,
    );
  }

  static UsageBudgetLedger normalize(
    UsageBudgetPolicy policy,
    UsageBudgetLedger ledger,
    DateTime now,
  ) {
    final today = dayKey(now);
    if (ledger.dayKey != today) {
      return initialLedger(policy, now);
    }

    final dailyRemaining = (policy.dailyCapSeconds - ledger.usedSecondsToday)
        .clamp(0, policy.dailyCapSeconds);
    if (dailyRemaining <= 0) {
      return ledger.copyWith(
        tokenSeconds: 0,
        lockedUntil: nextDay(now),
      );
    }

    final intervalMs = policy.refillIntervalMinutes * 60000;
    if (intervalMs <= 0) return ledger;

    final elapsedMs = now.difference(ledger.lastRefillAt).inMilliseconds;
    if (elapsedMs < intervalMs) {
      return ledger.copyWith(
        tokenSeconds: ledger.tokenSeconds.clamp(0, dailyRemaining),
        clearLockedUntil:
            ledger.lockedUntil != null && !ledger.lockedUntil!.isAfter(now),
      );
    }

    final ticks = elapsedMs ~/ intervalMs;
    final refill = ticks * policy.refillAmountSeconds;
    final maxTokens = policy.burstCapSeconds.clamp(0, dailyRemaining);
    final nextTokens = (ledger.tokenSeconds + refill).clamp(0, maxTokens);
    final nextRefill =
        ledger.lastRefillAt.add(Duration(milliseconds: ticks * intervalMs));

    return ledger.copyWith(
      tokenSeconds: nextTokens,
      lastRefillAt: nextRefill,
      clearLockedUntil:
          ledger.lockedUntil != null && !ledger.lockedUntil!.isAfter(now),
    );
  }

  static UsageBudgetSnapshot snapshot(
    UsageBudgetPolicy policy,
    UsageBudgetLedger ledger,
    DateTime now,
  ) {
    if (!policy.isWithinWindow(now)) {
      // 지정된 시간대 밖 — 나눠쓰기 제한을 적용하지 않음 (사용량도 세지 않음).
      final normalized = normalize(policy, ledger, now);
      return UsageBudgetSnapshot(
        policy: policy,
        ledger: normalized,
        isLocked: false,
        dailyRemainingSeconds:
            (policy.dailyCapSeconds - normalized.usedSecondsToday)
                .clamp(0, policy.dailyCapSeconds),
        availableSeconds: policy.dailyCapSeconds,
        lockedUntil: null,
      );
    }

    final normalized = normalize(policy, ledger, now);
    final dailyRemaining =
        (policy.dailyCapSeconds - normalized.usedSecondsToday)
            .clamp(0, policy.dailyCapSeconds);
    final lockedUntil = normalized.lockedUntil;
    final lockedByCooldown = lockedUntil != null && lockedUntil.isAfter(now);
    final lockedByDaily = dailyRemaining <= 0;
    final available = policy.enabled && !lockedByCooldown && !lockedByDaily
        ? normalized.tokenSeconds.clamp(0, dailyRemaining)
        : 0;

    return UsageBudgetSnapshot(
      policy: policy,
      ledger: normalized,
      isLocked: lockedByCooldown ||
          lockedByDaily ||
          (policy.enabled && available <= 0),
      dailyRemainingSeconds: dailyRemaining,
      availableSeconds: available,
      lockedUntil: lockedByDaily ? nextDay(now) : lockedUntil,
    );
  }

  static UsageBudgetLedger addUsage(
    UsageBudgetPolicy policy,
    UsageBudgetLedger ledger,
    int seconds,
    DateTime now,
  ) {
    if (seconds <= 0) return normalize(policy, ledger, now);
    if (!policy.isWithinWindow(now)) return normalize(policy, ledger, now);
    final snap = snapshot(policy, ledger, now);
    if (!snap.canCount) return snap.ledger;

    final count = seconds.clamp(0, snap.availableSeconds);
    final used =
        (snap.ledger.usedSecondsToday + count).clamp(0, policy.dailyCapSeconds);
    final tokens =
        (snap.ledger.tokenSeconds - count).clamp(0, policy.burstCapSeconds);
    final dailyRemaining =
        (policy.dailyCapSeconds - used).clamp(0, policy.dailyCapSeconds);
    DateTime? lockedUntil = snap.ledger.lockedUntil;

    if (dailyRemaining <= 0) {
      lockedUntil = nextDay(now);
    } else if (tokens <= 0) {
      lockedUntil = now.add(Duration(minutes: policy.cooldownMinutes));
    }

    return snap.ledger.copyWith(
      usedSecondsToday: used,
      tokenSeconds: tokens.clamp(0, dailyRemaining),
      lockedUntil: lockedUntil,
      clearLockedUntil: lockedUntil == null,
    );
  }
}
