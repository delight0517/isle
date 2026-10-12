import 'schedule_enforcement_mode.dart';
import 'schedule_slot.dart';

/// 스케줄 커밋먼트 잠금 중 — 편집 창 열릴 때 적용할 스케줄 레벨 필드 변경
/// (시간표·이름·모드·전체 on/off). 앱 타깃(③단계)은 [PendingScheduleTargetEdit]가
/// 이미 담당 — 이건 그 패턴을 ①②단계(시간표·이름·모드·enabled)까지 확장한 것
/// (2026-07-20 사용자 요청: "잠금 걸린 스케줄도 수동으로 적용을 눌러도 자동으로
/// timelock 이후에 적용되는 방식으로").
///
/// null 필드 = "이 필드는 안 바뀜" — 큐에 여러 번 요청이 들어와도 마지막
/// 요청이 건드린 필드만 덮어쓰고 나머지는 이전 대기 상태를 유지한다(예: 이름
/// 바꾸고 나서 시간대도 바꾸면, 최종 적용 시 이름·시간대 둘 다 반영).
class PendingScheduleFieldEdit {
  const PendingScheduleFieldEdit({
    required this.scheduleId,
    required this.applyAtMs,
    required this.scheduledAtMs,
    this.name,
    this.slots,
    this.enforcementMode,
    this.enabled,
  });

  final String scheduleId;
  final String? name;
  final List<ScheduleSlot>? slots;
  final ScheduleEnforcementMode? enforcementMode;
  final bool? enabled;
  final int applyAtMs;
  final int scheduledAtMs;

  bool get isEmpty =>
      name == null && slots == null && enforcementMode == null && enabled == null;

  DateTime get applyAt => DateTime.fromMillisecondsSinceEpoch(applyAtMs);

  Duration remaining([DateTime? at]) {
    final left = applyAt.difference(at ?? DateTime.now());
    if (left.isNegative) return Duration.zero;
    return left;
  }

  PendingScheduleFieldEdit mergedWith(PendingScheduleFieldEdit next) => PendingScheduleFieldEdit(
        scheduleId: scheduleId,
        applyAtMs: next.applyAtMs,
        scheduledAtMs: scheduledAtMs,
        name: next.name ?? name,
        slots: next.slots ?? slots,
        enforcementMode: next.enforcementMode ?? enforcementMode,
        enabled: next.enabled ?? enabled,
      );

  Map<String, dynamic> toJson() => {
        'schedule_id': scheduleId,
        if (name != null) 'name': name,
        if (slots != null) 'slots': slots!.map((s) => s.toJson()).toList(),
        if (enforcementMode != null) 'enforcement_mode': enforcementMode!.storageKey,
        if (enabled != null) 'enabled': enabled,
        'apply_at_ms': applyAtMs,
        'scheduled_at_ms': scheduledAtMs,
      };

  factory PendingScheduleFieldEdit.fromJson(Map<String, dynamic> j) => PendingScheduleFieldEdit(
        scheduleId: j['schedule_id'] as String? ?? '',
        name: j['name'] as String?,
        slots: (j['slots'] as List?)
            ?.map((e) => ScheduleSlot.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        enforcementMode: j['enforcement_mode'] != null
            ? ScheduleEnforcementModeX.parse(j['enforcement_mode'] as String?)
            : null,
        enabled: j['enabled'] as bool?,
        applyAtMs: (j['apply_at_ms'] as num?)?.toInt() ?? 0,
        scheduledAtMs: (j['scheduled_at_ms'] as num?)?.toInt() ?? 0,
      );
}
