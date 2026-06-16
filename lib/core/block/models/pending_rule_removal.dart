enum PendingRuleRemovalKind {
  keyword,
  blockedUrl,
}

class PendingRuleRemoval {
  const PendingRuleRemoval({
    required this.kind,
    required this.key,
    required this.removeAtMs,
    required this.scheduledAtMs,
  });

  final PendingRuleRemovalKind kind;
  final String key;
  final int removeAtMs;
  final int scheduledAtMs;

  DateTime get removeAt => DateTime.fromMillisecondsSinceEpoch(removeAtMs);

  Duration remaining([DateTime? at]) {
    final left = removeAt.difference(at ?? DateTime.now());
    if (left.isNegative) return Duration.zero;
    return left;
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'key': key,
        'remove_at_ms': removeAtMs,
        'scheduled_at_ms': scheduledAtMs,
      };

  factory PendingRuleRemoval.fromJson(Map<String, dynamic> j) =>
      PendingRuleRemoval(
        kind: PendingRuleRemovalKind.values.firstWhere(
          (e) => e.name == j['kind'],
          orElse: () => PendingRuleRemovalKind.keyword,
        ),
        key: j['key'] as String? ?? '',
        removeAtMs: (j['remove_at_ms'] as num?)?.toInt() ?? 0,
        scheduledAtMs: (j['scheduled_at_ms'] as num?)?.toInt() ?? 0,
      );
}
