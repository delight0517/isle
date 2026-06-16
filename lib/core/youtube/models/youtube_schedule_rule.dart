/// 요일·시간대 유튜브 잠금 (1=월 … 7=일, DateTime.weekday)
class YoutubeScheduleRule {
  final String id;
  final Set<int> weekdays;
  final int startMinutes;
  final int endMinutes;
  final bool enabled;

  const YoutubeScheduleRule({
    required this.id,
    required this.weekdays,
    required this.startMinutes,
    required this.endMinutes,
    this.enabled = true,
  });

  factory YoutubeScheduleRule.fromJson(Map<String, dynamic> j) => YoutubeScheduleRule(
        id: j['id'] as String? ?? '',
        weekdays: (j['weekdays'] as List? ?? [])
            .map((e) => (e as num).toInt())
            .where((d) => d >= 1 && d <= 7)
            .toSet(),
        startMinutes: (j['start_minutes'] as num?)?.toInt() ?? 0,
        endMinutes: (j['end_minutes'] as num?)?.toInt() ?? 0,
        enabled: j['enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'weekdays': weekdays.toList()..sort(),
        'start_minutes': startMinutes,
        'end_minutes': endMinutes,
        'enabled': enabled,
      };

  bool matchesNow(DateTime now) {
    if (!enabled || weekdays.isEmpty) return false;
    if (!weekdays.contains(now.weekday)) return false;
    final m = now.hour * 60 + now.minute;
    if (startMinutes <= endMinutes) {
      return m >= startMinutes && m < endMinutes;
    }
    return m >= startMinutes || m < endMinutes;
  }

  String label() {
    const names = ['', '월', '화', '수', '목', '금', '토', '일'];
    final days = weekdays.toList()..sort();
    final dayStr = days.map((d) => names[d]).join('·');
    return '$dayStr ${_fmt(startMinutes)}–${_fmt(endMinutes)}';
  }

  static String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
