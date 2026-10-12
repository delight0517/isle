/// 스케줄 ↔ 프리셋 차단 팩 연결 메타 (4VPN schedule pack sync 동일 개념)
class SchedulePremadePackLink {
  const SchedulePremadePackLink({
    required this.scheduleId,
    required this.packId,
    required this.version,
    required this.linkedAtMs,
  });

  final String scheduleId;
  final String packId;
  final String version;
  final int linkedAtMs;

  Map<String, dynamic> toJson() => {
        'schedule_id': scheduleId,
        'pack_id': packId,
        'version': version,
        'linked_at_ms': linkedAtMs,
      };

  factory SchedulePremadePackLink.fromJson(Map<String, dynamic> j) =>
      SchedulePremadePackLink(
        scheduleId: j['schedule_id'] as String? ?? '',
        packId: j['pack_id'] as String? ?? '',
        version: j['version'] as String? ?? '',
        linkedAtMs: (j['linked_at_ms'] as num?)?.toInt() ?? 0,
      );

  SchedulePremadePackLink copyWith({String? version, int? linkedAtMs}) =>
      SchedulePremadePackLink(
        scheduleId: scheduleId,
        packId: packId,
        version: version ?? this.version,
        linkedAtMs: linkedAtMs ?? this.linkedAtMs,
      );
}
