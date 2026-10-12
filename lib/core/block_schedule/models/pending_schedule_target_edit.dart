import 'schedule_app_target_entry.dart';

enum PendingScheduleTargetKind {
  entry,
  iosPickSync,
}

/// 스케줄 커밋먼트 잠금 중 — 편집 창 열릴 때 적용할 앱 타깃 변경
class PendingScheduleTargetEdit {
  const PendingScheduleTargetEdit({
    required this.scheduleId,
    required this.kind,
    required this.applyAtMs,
    required this.scheduledAtMs,
    this.targetId = '',
    this.entry,
  });

  final String scheduleId;
  final PendingScheduleTargetKind kind;
  final String targetId;
  final ScheduleAppTargetEntry? entry;
  final int applyAtMs;
  final int scheduledAtMs;

  DateTime get applyAt => DateTime.fromMillisecondsSinceEpoch(applyAtMs);

  Duration remaining([DateTime? at]) {
    final left = applyAt.difference(at ?? DateTime.now());
    if (left.isNegative) return Duration.zero;
    return left;
  }

  Map<String, dynamic> toJson() => {
        'schedule_id': scheduleId,
        'kind': kind.name,
        'target_id': targetId,
        if (entry != null) 'entry': entry!.toJson(),
        'apply_at_ms': applyAtMs,
        'scheduled_at_ms': scheduledAtMs,
      };

  factory PendingScheduleTargetEdit.fromJson(Map<String, dynamic> j) =>
      PendingScheduleTargetEdit(
        scheduleId: j['schedule_id'] as String? ?? '',
        kind: PendingScheduleTargetKind.values.firstWhere(
          (e) => e.name == j['kind'],
          orElse: () => PendingScheduleTargetKind.entry,
        ),
        targetId: j['target_id'] as String? ?? '',
        entry: j['entry'] != null
            ? ScheduleAppTargetEntry.fromJson(
                Map<String, dynamic>.from(j['entry'] as Map),
              )
            : null,
        applyAtMs: (j['apply_at_ms'] as num?)?.toInt() ?? 0,
        scheduledAtMs: (j['scheduled_at_ms'] as num?)?.toInt() ?? 0,
      );
}
