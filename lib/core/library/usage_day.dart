/// 사용량 카운팅의 **단일 날짜 경계** — 모든 usage/watch-limit store가 이 한 곳에서
/// 로컬 달력일(day key)과 자정 경계를 계산한다.
///
/// 예전에는 `${year}-${month}-${day}` day-key 로직이 6개 store에 복붙돼 있어,
/// 한 곳이라도 어긋나면 카운트가 desync될 위험이 있었다. 모두 이 헬퍼로 통일한다.
class UsageDay {
  UsageDay._();

  /// 로컬 시간 기준 오늘 키 (`YYYY-MM-DD`).
  static String key([DateTime? at]) {
    final n = at ?? DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  /// 다음 로컬 자정(내일 00:00). 일일 한도 리셋 기준.
  static DateTime nextMidnight([DateTime? at]) {
    final n = at ?? DateTime.now();
    return DateTime(n.year, n.month, n.day + 1);
  }

  /// 지금부터 다음 자정까지 남은 시간.
  static Duration timeUntilMidnight([DateTime? at]) {
    final n = at ?? DateTime.now();
    return nextMidnight(n).difference(n);
  }

  /// 이 주의 월요일 00:00(로컬 시간) — 주간 사용량/한도 리셋 기준.
  static DateTime weekStart([DateTime? at]) {
    final n = at ?? DateTime.now();
    return DateTime(n.year, n.month, n.day - (n.weekday - 1));
  }

  /// 주 단위 키(`YYYY-MM-DD`, 그 주 월요일 날짜) — 주가 바뀌면 값이 달라지므로
  /// "이번주만" 같은 임시 설정의 만료 판정에 그대로 쓸 수 있다.
  static String weekKey([DateTime? at]) => key(weekStart(at));
}
