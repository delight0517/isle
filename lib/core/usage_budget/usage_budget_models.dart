class UsageBudgetTarget {
  const UsageBudgetTarget._();

  static const youtube = 'youtube';
  static const instagram = 'instagram';
  static const brunch = 'brunch';

  static String app(String appId) => 'app:$appId';

  static String label(String target) {
    switch (target) {
      case youtube:
        return 'YouTube';
      case instagram:
        return 'Instagram';
      case brunch:
        return 'Brunch';
      default:
        if (target.startsWith('app:')) return target.substring(4);
        return target;
    }
  }
}

class UsageBudgetPolicy {
  const UsageBudgetPolicy({
    required this.target,
    required this.enabled,
    required this.dailyCapMinutes,
    required this.burstCapMinutes,
    required this.refillAmountMinutes,
    required this.refillIntervalMinutes,
    required this.cooldownMinutes,
    required this.updatedAt,
    this.windowStartMinute,
    this.windowEndMinute,
  });

  final String target;
  final bool enabled;
  final int dailyCapMinutes;
  final int burstCapMinutes;
  final int refillAmountMinutes;
  final int refillIntervalMinutes;
  final int cooldownMinutes;
  final DateTime updatedAt;

  /// 정책이 적용되는 시간대 (분 단위, 0–1439). 둘 다 null이면 하루 종일 적용.
  /// start > end면 자정을 넘는 구간으로 취급 (예: 23:00–다음날 12:00).
  final int? windowStartMinute;
  final int? windowEndMinute;

  int get dailyCapSeconds => dailyCapMinutes * 60;
  int get burstCapSeconds => burstCapMinutes * 60;
  int get refillAmountSeconds => refillAmountMinutes * 60;

  bool get hasWindow => windowStartMinute != null && windowEndMinute != null;

  bool isWithinWindow(DateTime at) {
    if (!hasWindow) return true;
    final minuteOfDay = at.hour * 60 + at.minute;
    final start = windowStartMinute!;
    final end = windowEndMinute!;
    if (start <= end) return minuteOfDay >= start && minuteOfDay < end;
    return minuteOfDay >= start || minuteOfDay < end;
  }

  UsageBudgetPolicy copyWith({
    bool? enabled,
    int? dailyCapMinutes,
    int? burstCapMinutes,
    int? refillAmountMinutes,
    int? refillIntervalMinutes,
    int? cooldownMinutes,
    DateTime? updatedAt,
    int? windowStartMinute,
    int? windowEndMinute,
    bool clearWindow = false,
  }) {
    return UsageBudgetPolicy(
      target: target,
      enabled: enabled ?? this.enabled,
      dailyCapMinutes: dailyCapMinutes ?? this.dailyCapMinutes,
      burstCapMinutes: burstCapMinutes ?? this.burstCapMinutes,
      refillAmountMinutes: refillAmountMinutes ?? this.refillAmountMinutes,
      refillIntervalMinutes:
          refillIntervalMinutes ?? this.refillIntervalMinutes,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      updatedAt: updatedAt ?? this.updatedAt,
      windowStartMinute:
          clearWindow ? null : windowStartMinute ?? this.windowStartMinute,
      windowEndMinute:
          clearWindow ? null : windowEndMinute ?? this.windowEndMinute,
    );
  }

  Map<String, dynamic> toJson() => {
        'target': target,
        'enabled': enabled,
        'dailyCapMinutes': dailyCapMinutes,
        'burstCapMinutes': burstCapMinutes,
        'refillAmountMinutes': refillAmountMinutes,
        'refillIntervalMinutes': refillIntervalMinutes,
        'cooldownMinutes': cooldownMinutes,
        'updatedAt': updatedAt.toIso8601String(),
        'windowStartMinute': windowStartMinute,
        'windowEndMinute': windowEndMinute,
      };

  factory UsageBudgetPolicy.fromJson(Map<String, dynamic> json) {
    return UsageBudgetPolicy(
      target: (json['target'] as String?)?.trim().isNotEmpty == true
          ? (json['target'] as String).trim()
          : UsageBudgetTarget.youtube,
      enabled: json['enabled'] as bool? ?? false,
      dailyCapMinutes: (json['dailyCapMinutes'] as num?)?.toInt() ?? 60,
      burstCapMinutes: (json['burstCapMinutes'] as num?)?.toInt() ?? 20,
      refillAmountMinutes: (json['refillAmountMinutes'] as num?)?.toInt() ?? 20,
      refillIntervalMinutes:
          (json['refillIntervalMinutes'] as num?)?.toInt() ?? 60,
      cooldownMinutes: (json['cooldownMinutes'] as num?)?.toInt() ?? 60,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      windowStartMinute: (json['windowStartMinute'] as num?)?.toInt(),
      windowEndMinute: (json['windowEndMinute'] as num?)?.toInt(),
    );
  }
}

class UsageBudgetPendingPolicy {
  const UsageBudgetPendingPolicy({
    required this.policy,
    required this.applyAt,
    required this.scheduledAt,
    required this.carryUsedSecondsToday,
  });

  final UsageBudgetPolicy policy;
  final DateTime applyAt;
  final DateTime scheduledAt;
  final int carryUsedSecondsToday;

  String get target => policy.target;

  Duration remaining([DateTime? at]) {
    final left = applyAt.difference(at ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Map<String, dynamic> toJson() => {
        'policy': policy.toJson(),
        'applyAt': applyAt.toIso8601String(),
        'scheduledAt': scheduledAt.toIso8601String(),
        'carryUsedSecondsToday': carryUsedSecondsToday,
      };

  factory UsageBudgetPendingPolicy.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return UsageBudgetPendingPolicy(
      policy: UsageBudgetPolicy.fromJson(
        Map<String, dynamic>.from(json['policy'] as Map? ?? const {}),
      ),
      applyAt: DateTime.tryParse(json['applyAt'] as String? ?? '') ?? now,
      scheduledAt:
          DateTime.tryParse(json['scheduledAt'] as String? ?? '') ?? now,
      carryUsedSecondsToday:
          (json['carryUsedSecondsToday'] as num?)?.toInt() ?? 0,
    );
  }
}

class UsageBudgetLedger {
  const UsageBudgetLedger({
    required this.dayKey,
    required this.usedSecondsToday,
    required this.tokenSeconds,
    required this.lastRefillAt,
    this.lockedUntil,
  });

  final String dayKey;
  final int usedSecondsToday;
  final int tokenSeconds;
  final DateTime lastRefillAt;
  final DateTime? lockedUntil;

  UsageBudgetLedger copyWith({
    String? dayKey,
    int? usedSecondsToday,
    int? tokenSeconds,
    DateTime? lastRefillAt,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
  }) {
    return UsageBudgetLedger(
      dayKey: dayKey ?? this.dayKey,
      usedSecondsToday: usedSecondsToday ?? this.usedSecondsToday,
      tokenSeconds: tokenSeconds ?? this.tokenSeconds,
      lastRefillAt: lastRefillAt ?? this.lastRefillAt,
      lockedUntil: clearLockedUntil ? null : lockedUntil ?? this.lockedUntil,
    );
  }

  Map<String, dynamic> toJson() => {
        'dayKey': dayKey,
        'usedSecondsToday': usedSecondsToday,
        'tokenSeconds': tokenSeconds,
        'lastRefillAt': lastRefillAt.toIso8601String(),
        'lockedUntil': lockedUntil?.toIso8601String(),
      };

  factory UsageBudgetLedger.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return UsageBudgetLedger(
      dayKey: json['dayKey'] as String? ?? '',
      usedSecondsToday: (json['usedSecondsToday'] as num?)?.toInt() ?? 0,
      tokenSeconds: (json['tokenSeconds'] as num?)?.toInt() ?? 0,
      lastRefillAt:
          DateTime.tryParse(json['lastRefillAt'] as String? ?? '') ?? now,
      lockedUntil: DateTime.tryParse(json['lockedUntil'] as String? ?? ''),
    );
  }
}

class UsageBudgetSnapshot {
  const UsageBudgetSnapshot({
    required this.policy,
    required this.ledger,
    required this.isLocked,
    required this.dailyRemainingSeconds,
    required this.availableSeconds,
    this.lockedUntil,
  });

  final UsageBudgetPolicy policy;
  final UsageBudgetLedger ledger;
  final bool isLocked;
  final int dailyRemainingSeconds;
  final int availableSeconds;
  final DateTime? lockedUntil;

  bool get canCount => policy.enabled && !isLocked && availableSeconds > 0;
}
