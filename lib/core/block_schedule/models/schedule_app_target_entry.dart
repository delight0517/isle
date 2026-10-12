/// 스케줄별 앱 타깃 — 차단·시간 한도
class ScheduleAppTargetEntry {
  const ScheduleAppTargetEntry({
    required this.targetId,
    this.blockInSlot = false,
    this.limitEnabled = false,
    this.limitMinutes = 10,
    this.windowMinutes = 60,
    this.dailyLimitMinutes,
  });

  final String targetId;
  final bool blockInSlot;
  final bool limitEnabled;
  final int limitMinutes;
  final int windowMinutes;

  /// 시간당(등) 리필 한도와 별개인 **진짜 하루 총량 상한** — null이면 없음.
  /// 리필 한도만 있으면 "시간당 N분 × 활성 시간대"로 하루 총량이 에뮬레이트만
  /// 되고 진짜 하드 컷은 없었다(2026-07-20 — 안전 라인 스펙 "하루 2시간이
  /// 최대"를 문자 그대로 강제하려면 이 필드가 필요).
  final int? dailyLimitMinutes;

  Map<String, dynamic> toJson() => {
        'target_id': targetId,
        'block_in_slot': blockInSlot,
        'limit_enabled': limitEnabled,
        'limit_minutes': limitMinutes,
        'window_minutes': windowMinutes,
        if (dailyLimitMinutes != null) 'daily_limit_minutes': dailyLimitMinutes,
      };

  factory ScheduleAppTargetEntry.fromJson(Map<String, dynamic> j) => ScheduleAppTargetEntry(
        targetId: j['target_id'] as String? ?? '',
        blockInSlot: j['block_in_slot'] as bool? ?? false,
        limitEnabled: j['limit_enabled'] as bool? ?? false,
        limitMinutes: (j['limit_minutes'] as num?)?.toInt() ?? 10,
        windowMinutes: (j['window_minutes'] as num?)?.toInt() ?? 60,
        dailyLimitMinutes: (j['daily_limit_minutes'] as num?)?.toInt(),
      );

  ScheduleAppTargetEntry copyWith({
    bool? blockInSlot,
    bool? limitEnabled,
    int? limitMinutes,
    int? windowMinutes,
    int? dailyLimitMinutes,
  }) =>
      ScheduleAppTargetEntry(
        targetId: targetId,
        blockInSlot: blockInSlot ?? this.blockInSlot,
        limitEnabled: limitEnabled ?? this.limitEnabled,
        limitMinutes: limitMinutes ?? this.limitMinutes,
        windowMinutes: windowMinutes ?? this.windowMinutes,
        dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      );
}
