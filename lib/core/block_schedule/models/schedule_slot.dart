/// 요일 슬롯 — day 0=월 … 6=일 (블루프린트 §3)
class ScheduleSlot {
  final int day;
  final int startMinute;
  final int endMinute;

  const ScheduleSlot({
    required this.day,
    required this.startMinute,
    required this.endMinute,
  });

  Map<String, dynamic> toJson() => {
        'day': day,
        'start_minute': startMinute,
        'end_minute': endMinute,
      };

  factory ScheduleSlot.fromJson(Map<String, dynamic> j) => ScheduleSlot(
        day: (j['day'] as num?)?.toInt() ?? 0,
        startMinute: (j['start_minute'] as num?)?.toInt() ?? 0,
        endMinute: (j['end_minute'] as num?)?.toInt() ?? 0,
      );

  /// [now]의 분(0–1439)이 이 슬롯에 포함되는지
  bool coversMinute(int minuteOfDay) {
    if (startMinute <= endMinute) {
      return minuteOfDay >= startMinute && minuteOfDay < endMinute;
    }
    return minuteOfDay >= startMinute || minuteOfDay < endMinute;
  }

  bool isActiveOn(DateTime now) {
    final day = now.weekday - 1;
    if (day != this.day) return false;
    return coversMinute(now.hour * 60 + now.minute);
  }

  String label() {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final d = day.clamp(0, 6);
    return '${days[d]} ${_t(startMinute)}–${_t(endMinute)}';
  }

  static String _t(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}
