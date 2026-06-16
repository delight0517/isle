/// 스케줄별 앱 타깃 — 차단·시간 한도
class ScheduleAppTargetEntry {
  const ScheduleAppTargetEntry({
    required this.targetId,
    this.blockInSlot = false,
    this.limitEnabled = false,
    this.limitMinutes = 10,
    this.windowMinutes = 60,
  });

  final String targetId;
  final bool blockInSlot;
  final bool limitEnabled;
  final int limitMinutes;
  final int windowMinutes;

  Map<String, dynamic> toJson() => {
        'target_id': targetId,
        'block_in_slot': blockInSlot,
        'limit_enabled': limitEnabled,
        'limit_minutes': limitMinutes,
        'window_minutes': windowMinutes,
      };

  factory ScheduleAppTargetEntry.fromJson(Map<String, dynamic> j) => ScheduleAppTargetEntry(
        targetId: j['target_id'] as String? ?? '',
        blockInSlot: j['block_in_slot'] as bool? ?? false,
        limitEnabled: j['limit_enabled'] as bool? ?? false,
        limitMinutes: (j['limit_minutes'] as num?)?.toInt() ?? 10,
        windowMinutes: (j['window_minutes'] as num?)?.toInt() ?? 60,
      );

  ScheduleAppTargetEntry copyWith({
    bool? blockInSlot,
    bool? limitEnabled,
    int? limitMinutes,
    int? windowMinutes,
  }) =>
      ScheduleAppTargetEntry(
        targetId: targetId,
        blockInSlot: blockInSlot ?? this.blockInSlot,
        limitEnabled: limitEnabled ?? this.limitEnabled,
        limitMinutes: limitMinutes ?? this.limitMinutes,
        windowMinutes: windowMinutes ?? this.windowMinutes,
      );
}
