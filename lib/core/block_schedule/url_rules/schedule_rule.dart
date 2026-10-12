import 'schedule_rule_kind.dart';

class ScheduleRule {
  final String id;
  final String scheduleId;
  final ScheduleRuleKind kind;
  final String pattern;
  final String? rawInput;
  final int addedAtMs;
  /// 프리셋 팩에서 추가된 규칙 — 해제 시 일괄 삭제용
  final String? premadePackId;

  const ScheduleRule({
    required this.id,
    required this.scheduleId,
    required this.kind,
    required this.pattern,
    this.rawInput,
    required this.addedAtMs,
    this.premadePackId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'schedule_id': scheduleId,
        'kind': kind.storageKey,
        'pattern': pattern,
        if (rawInput != null) 'raw_input': rawInput,
        'added_at_ms': addedAtMs,
        if (premadePackId != null) 'premade_pack_id': premadePackId,
      };

  factory ScheduleRule.fromJson(Map<String, dynamic> j) => ScheduleRule(
        id: j['id'] as String? ?? '',
        scheduleId: j['schedule_id'] as String? ?? '',
        kind: ScheduleRuleKindX.parse(j['kind'] as String?),
        pattern: (j['pattern'] as String? ?? '').toLowerCase().trim(),
        rawInput: j['raw_input'] as String?,
        addedAtMs: (j['added_at_ms'] as num?)?.toInt() ?? 0,
        premadePackId: j['premade_pack_id'] as String?,
      );

  ScheduleRule copyWith({
    String? pattern,
    String? rawInput,
    String? premadePackId,
  }) =>
      ScheduleRule(
        id: id,
        scheduleId: scheduleId,
        kind: kind,
        pattern: pattern ?? this.pattern,
        rawInput: rawInput ?? this.rawInput,
        addedAtMs: addedAtMs,
        premadePackId: premadePackId ?? this.premadePackId,
      );
}
