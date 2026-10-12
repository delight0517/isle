import 'kakao_shorts_addiction_store.dart';
import 'kakao_shorts_session.dart';

enum KakaoShortsRiskLevel { low, medium, high }

class KakaoShortsInsight {
  const KakaoShortsInsight({
    required this.riskLevel,
    required this.totalMinutesToday,
    required this.longestStreakMinutes,
    required this.sessionCountToday,
    required this.headline,
    required this.detail,
  });

  final KakaoShortsRiskLevel riskLevel;
  final int totalMinutesToday;
  final int longestStreakMinutes;
  final int sessionCountToday;
  final String headline;
  final String detail;
}

/// 연속 시청·일일 합계 기반 코칭 (로컬만 · API 없음)
class KakaoShortsAddictionAnalyzer {
  KakaoShortsAddictionAnalyzer._();

  static KakaoShortsInsight analyze({DateTime? now}) {
    final n = now ?? DateTime.now();
    final todayStart = DateTime(n.year, n.month, n.day);
    // start만 보고 자정 이전이면 오늘 세션에서 통째로 빠졌다 — 23시대에
    // 시작해 자정을 넘겨 끝나는(또는 아직 진행 중인) 세션이 "오늘" 통계에서
    // 전부 사라지던 버그(2026-07-20 발견). end(진행 중이면 now)가 오늘
    // 시작 이후면 포함 — CAGE의 야간 스케줄 자정 경계 버그와 같은 종류.
    final sessions = KakaoShortsAddictionStore.loadSessions()
        .where((s) {
          if (s.isOpen) {
            // 못 닫힌 채 계속 열려 있는 세션이 "매일 오늘 것"으로 무한히
            // 잡히지 않도록 — 24시간 넘게 열려 있으면 방치된 것으로 보고 제외.
            final start = DateTime.fromMillisecondsSinceEpoch(s.startMs);
            return !n.difference(start).isNegative &&
                n.difference(start) <= const Duration(hours: 24);
          }
          final end = DateTime.fromMillisecondsSinceEpoch(s.endMs!);
          return end.isAfter(todayStart);
        })
        .toList();

    var totalSec = 0;
    var longestMin = 0;
    for (final s in sessions) {
      final sec = s.durationSeconds(nowMs: n.millisecondsSinceEpoch);
      totalSec += sec;
      final min = (sec / 60).ceil();
      if (min > longestMin) longestMin = min;
    }

    final totalMin = (totalSec / 60).ceil();
    final count = sessions.length;
    final onBreak = KakaoShortsAddictionStore.isOnBreak;
    final pomodoro = KakaoShortsAddictionStore.pomodoroEnabled;

    KakaoShortsRiskLevel risk;
    if (totalMin >= 60 || longestMin >= 35 || count >= 4) {
      risk = KakaoShortsRiskLevel.high;
    } else if (totalMin >= 30 || longestMin >= 20 || count >= 2) {
      risk = KakaoShortsRiskLevel.medium;
    } else {
      risk = KakaoShortsRiskLevel.low;
    }

    final headline = switch (risk) {
      KakaoShortsRiskLevel.high =>
        '오늘 쇼츠 패턴이 강해요 — OS 차단+5분 리필을 권장해요',
      KakaoShortsRiskLevel.medium => '쇼츠가 습관처럼 쌓이고 있어요',
      KakaoShortsRiskLevel.low => onBreak
          ? '휴식 시간이에요 — 잠깐 카카오톡에서 손 떼기'
          : '오늘은 비교적 여유로운 편이에요',
    };

    final buffer = StringBuffer()
      ..write('오늘 약 $totalMin분 · 세션 $count회 · 최장 연속 $longestMin분.');
    if (pomodoro && onBreak) {
      final left = KakaoShortsAddictionStore.breakRemaining;
      if (left != null) {
        buffer.write(' ${left.inMinutes}분 뒤 다시 집중 창이 열려요.');
      }
    } else if (pomodoro) {
      final used = KakaoShortsAddictionStore.workSecondsInCycle ~/ 60;
      buffer.write(' 이번 집중 창 $used/${KakaoShortsAddictionStore.defaultWorkMinutes}분.');
    }
    buffer.write(
      ' 카카오톡 앱 차단과 5분마다 3분만 허용(리필)이 쇼츠 사용 줄이기에 도움이 됩니다.',
    );

    return KakaoShortsInsight(
      riskLevel: risk,
      totalMinutesToday: totalMin,
      longestStreakMinutes: longestMin,
      sessionCountToday: count,
      headline: headline,
      detail: buffer.toString(),
    );
  }

  static List<KakaoShortsSession> sessionsLastDays(int days) {
    final cut = DateTime.now().subtract(Duration(days: days));
    return KakaoShortsAddictionStore.loadSessions().where((s) {
      return DateTime.fromMillisecondsSinceEpoch(s.startMs).isAfter(cut);
    }).toList();
  }
}
