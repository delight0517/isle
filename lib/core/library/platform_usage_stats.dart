import 'dart:io' show Platform;

import '../platform/mac_browser_session_service.dart';
import 'engagement_tracker.dart';
import 'platform_watch_limit_store.dart';

/// 인스타·유튜브·브런치 — 앱 내 체류 시간 집계 (EngagementTracker 기반)
class PlatformUsageStats {
  PlatformUsageStats._();

  static const platforms = ['youtube', 'instagram', 'brunch'];

  static const _labels = {
    'youtube': 'YouTube',
    'instagram': 'Instagram',
    'brunch': 'Brunch',
  };

  static const _watchIds = {
    'youtube': PlatformWatchId.youtube,
    'instagram': PlatformWatchId.instagram,
    'brunch': PlatformWatchId.brunch,
  };

  static String labelFor(String platform) => _labels[platform] ?? platform;

  static Future<Map<String, int>> secondsByPlatform() async {
    await EngagementTracker.ensureOpen();
    final screens = EngagementTracker.screenSecondsRaw();
    final out = {for (final p in platforms) p: 0};
    for (final e in screens.entries) {
      final id = e.key.toLowerCase();
      for (final p in platforms) {
        if (id.contains(p)) {
          out[p] = (out[p] ?? 0) + e.value;
        }
      }
    }
    try {
      await PlatformWatchLimitStore.ensureOpen();
      for (final e in _watchIds.entries) {
        out[e.key] = _max(
          out[e.key] ?? 0,
          PlatformWatchLimitStore.secondsUsedToday(e.value),
        );
      }
    } catch (_) {
      // best-effort; EngagementTracker 기록만으로도 화면은 표시 가능하다.
    }
    return out;
  }

  /// 최근 N일 × 플랫폼별 초.
  ///
  /// EngagementTracker가 정본이지만, 과거 버전은 시간 한도용 timer만 갱신하는
  /// 경우가 있어 오늘 값은 한도 store와 병합한다.
  static Future<Map<String, Map<String, int>>> dailyByPlatform({
    int days = 7,
  }) async {
    await EngagementTracker.ensureOpen();
    final daily = EngagementTracker.dailyByPlatform(
      platforms: platforms,
      days: days,
    );
    if (daily.isEmpty) return daily;
    final todayKey = _todayKey();
    final today = await todayByPlatform();
    daily[todayKey] = {
      ...?daily[todayKey],
      for (final p in platforms)
        p: _max(daily[todayKey]?[p] ?? 0, today[p] ?? 0),
    };
    return daily;
  }

  /// 오늘 플랫폼별 초. 화면 표시는 한도 on/off와 무관해야 하므로
  /// EngagementTracker 값과 PlatformWatchLimitStore 값을 큰 쪽으로 병합한다.
  static Future<Map<String, int>> todayByPlatform() async {
    await EngagementTracker.ensureOpen();
    final today = EngagementTracker.todayByPlatform(platforms);
    try {
      await PlatformWatchLimitStore.ensureOpen();
      for (final e in _watchIds.entries) {
        final limitStoreSeconds =
            PlatformWatchLimitStore.secondsUsedToday(e.value);
        today[e.key] = _max(today[e.key] ?? 0, limitStoreSeconds);
      }
    } catch (_) {
      // 통계 화면은 best-effort. Hive 초기화/마이그레이션 중이어도 기본 기록은 표시한다.
    }
    return today;
  }

  /// macOS — Safari·Chrome 전면 시간 (네이티브 5초 tick)
  static Future<int> macBrowserSecondsToday() async {
    if (!Platform.isMacOS) return 0;
    final minutes = await MacBrowserSessionService.browserMinutesToday();
    return minutes * 60;
  }

  static Future<PlatformUsageReport> buildReport({int days = 7}) async {
    final totalByPlatform = await secondsByPlatform();
    final today = await todayByPlatform();
    final daily = await dailyByPlatform(days: days);
    final hourly = EngagementTracker.hourlyByPlatform(
      platforms: platforms,
      days: days,
    );
    final macBrowserSec = await macBrowserSecondsToday();
    final totalSeconds = totalByPlatform.values.fold<int>(0, (a, b) => a + b);
    final sevenDaySeconds = daily.values.fold<int>(
      0,
      (sum, row) => sum + row.values.fold<int>(0, (a, b) => a + b),
    );
    final activeDays = daily.values
        .where((row) => row.values.fold<int>(0, (a, b) => a + b) > 0)
        .length;
    final averageSeconds = days <= 0 ? 0 : sevenDaySeconds ~/ days;
    final activeAverageSeconds =
        activeDays == 0 ? 0 : sevenDaySeconds ~/ activeDays;

    final topPlatform = _topEntry(totalByPlatform);
    final busiestDay = _topDailyEntry(daily);
    final busiestHour = _topHourlyEntry(hourly);

    final reasons = <String>[
      if (totalSeconds == 0)
        '아직 앱 안 사용 기록이 없어 판단을 보류했어요.'
      else
        '총 사용량은 Isle 앱 안 WebView 체류 시간과 오늘 한도 타이머 값을 큰 쪽으로 병합했어요.',
      if (sevenDaySeconds > 0)
        '최근 $days일 평균은 일별 버킷 ${daily.length}개를 기준으로 계산했어요.',
      if (busiestDay != null)
        '가장 많이 쓴 날은 ${busiestDay.day}이고 ${formatDuration(busiestDay.seconds)}였어요.',
      if (busiestHour != null)
        '가장 많이 쓰는 시간대는 ${busiestHour.label}이고 ${formatDuration(busiestHour.seconds)}였어요.',
      if (busiestHour == null) '시간대 분석은 이번 버전부터 기록되는 hourly 버킷이 쌓이면 정확해져요.',
      if (topPlatform != null)
        '가장 많이 쓴 플랫폼은 ${labelFor(topPlatform.key)}이며 전체의 ${(topPlatform.value / totalSeconds * 100).round()}%예요.',
      if (Platform.isMacOS && macBrowserSec > 0)
        'Mac Safari·Chrome 전면 시간은 별도 네이티브 tick으로 참고값만 함께 보여줘요.',
    ];

    return PlatformUsageReport(
      generatedAt: DateTime.now(),
      days: days,
      totalByPlatform: totalByPlatform,
      todayByPlatform: today,
      dailyByPlatform: daily,
      hourlyByPlatform: hourly,
      totalSeconds: totalSeconds,
      sevenDaySeconds: sevenDaySeconds,
      averageSecondsPerDay: averageSeconds,
      activeAverageSecondsPerDay: activeAverageSeconds,
      activeDays: activeDays,
      macBrowserSecondsToday: macBrowserSec,
      topPlatform: topPlatform == null
          ? null
          : PlatformUsageRank(topPlatform.key, topPlatform.value),
      busiestDay: busiestDay,
      busiestHour: busiestHour,
      reasons: reasons,
    );
  }

  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0분';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '$h시간 $m분';
    if (m > 0) return '$m분';
    return '$seconds초';
  }

  static int _max(int a, int b) => a > b ? a : b;

  static MapEntry<String, int>? _topEntry(Map<String, int> values) {
    MapEntry<String, int>? best;
    for (final e in values.entries) {
      if (e.value <= 0) continue;
      if (best == null || e.value > best.value) best = e;
    }
    return best;
  }

  static PlatformUsageDay? _topDailyEntry(
    Map<String, Map<String, int>> daily,
  ) {
    PlatformUsageDay? best;
    for (final e in daily.entries) {
      final seconds = e.value.values.fold<int>(0, (a, b) => a + b);
      if (seconds <= 0) continue;
      if (best == null || seconds > best.seconds) {
        best = PlatformUsageDay(e.key, seconds);
      }
    }
    return best;
  }

  static PlatformUsageHour? _topHourlyEntry(
    Map<int, Map<String, int>> hourly,
  ) {
    PlatformUsageHour? best;
    for (final e in hourly.entries) {
      final seconds = e.value.values.fold<int>(0, (a, b) => a + b);
      if (seconds <= 0) continue;
      if (best == null || seconds > best.seconds) {
        best = PlatformUsageHour(e.key, seconds);
      }
    }
    return best;
  }

  static String _todayKey() {
    final d = DateTime.now().toLocal();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}

class PlatformUsageReport {
  const PlatformUsageReport({
    required this.generatedAt,
    required this.days,
    required this.totalByPlatform,
    required this.todayByPlatform,
    required this.dailyByPlatform,
    required this.hourlyByPlatform,
    required this.totalSeconds,
    required this.sevenDaySeconds,
    required this.averageSecondsPerDay,
    required this.activeAverageSecondsPerDay,
    required this.activeDays,
    required this.macBrowserSecondsToday,
    required this.topPlatform,
    required this.busiestDay,
    required this.busiestHour,
    required this.reasons,
  });

  final DateTime generatedAt;
  final int days;
  final Map<String, int> totalByPlatform;
  final Map<String, int> todayByPlatform;
  final Map<String, Map<String, int>> dailyByPlatform;
  final Map<int, Map<String, int>> hourlyByPlatform;
  final int totalSeconds;
  final int sevenDaySeconds;
  final int averageSecondsPerDay;
  final int activeAverageSecondsPerDay;
  final int activeDays;
  final int macBrowserSecondsToday;
  final PlatformUsageRank? topPlatform;
  final PlatformUsageDay? busiestDay;
  final PlatformUsageHour? busiestHour;
  final List<String> reasons;

  String copyLog() {
    final b = StringBuffer()
      ..writeln('=== Isle 사용 시간 리포트 ===')
      ..writeln('생성: ${generatedAt.toIso8601String()}')
      ..writeln('분석 범위: 최근 $days일')
      ..writeln(
          '데이터 출처: EngagementTracker screen/daily/hourly + PlatformWatchLimitStore today fallback')
      ..writeln('')
      ..writeln('[요약]')
      ..writeln('총 앱 안 사용량: ${PlatformUsageStats.formatDuration(totalSeconds)}')
      ..writeln(
          '최근 $days일 합계: ${PlatformUsageStats.formatDuration(sevenDaySeconds)}')
      ..writeln(
          '최근 $days일 일평균: ${PlatformUsageStats.formatDuration(averageSecondsPerDay)}')
      ..writeln(
          '사용한 날 기준 평균: ${PlatformUsageStats.formatDuration(activeAverageSecondsPerDay)} ($activeDays일)')
      ..writeln(
          '최다 플랫폼: ${topPlatform == null ? '없음' : '${PlatformUsageStats.labelFor(topPlatform!.platform)} ${PlatformUsageStats.formatDuration(topPlatform!.seconds)}'}')
      ..writeln(
          '최다 사용일: ${busiestDay == null ? '없음' : '${busiestDay!.day} ${PlatformUsageStats.formatDuration(busiestDay!.seconds)}'}')
      ..writeln(
          '최다 시간대: ${busiestHour == null ? '데이터 부족' : '${busiestHour!.label} ${PlatformUsageStats.formatDuration(busiestHour!.seconds)}'}')
      ..writeln('');

    b.writeln('[플랫폼별 총량]');
    for (final p in PlatformUsageStats.platforms) {
      b.writeln(
          '- ${PlatformUsageStats.labelFor(p)}: ${PlatformUsageStats.formatDuration(totalByPlatform[p] ?? 0)}');
    }
    if (macBrowserSecondsToday > 0) {
      b.writeln(
          '- Safari·Chrome(Mac 오늘): ${PlatformUsageStats.formatDuration(macBrowserSecondsToday)}');
    }

    b.writeln('');
    b.writeln('[최근 $days일 일별]');
    for (final e in dailyByPlatform.entries) {
      final sum = e.value.values.fold<int>(0, (a, b) => a + b);
      final parts = PlatformUsageStats.platforms
          .map((p) =>
              '${PlatformUsageStats.labelFor(p)} ${PlatformUsageStats.formatDuration(e.value[p] ?? 0)}')
          .join(', ');
      b.writeln(
          '- ${e.key}: ${PlatformUsageStats.formatDuration(sum)} ($parts)');
    }

    b.writeln('');
    b.writeln('[시간대 TOP]');
    final hourlyRows = hourlyByPlatform.entries.toList()
      ..sort((a, b) {
        final av = a.value.values.fold<int>(0, (x, y) => x + y);
        final bv = b.value.values.fold<int>(0, (x, y) => x + y);
        return bv.compareTo(av);
      });
    var wroteHour = false;
    for (final e in hourlyRows.take(5)) {
      final sum = e.value.values.fold<int>(0, (a, b) => a + b);
      if (sum <= 0) continue;
      wroteHour = true;
      b.writeln(
          '- ${PlatformUsageHour(e.key, sum).label}: ${PlatformUsageStats.formatDuration(sum)}');
    }
    if (!wroteHour) b.writeln('- 데이터 부족: 이 버전 이후 사용 기록부터 쌓입니다.');

    b.writeln('');
    b.writeln('[판단 이유]');
    for (final r in reasons) {
      b.writeln('- $r');
    }
    return b.toString();
  }
}

class PlatformUsageRank {
  const PlatformUsageRank(this.platform, this.seconds);

  final String platform;
  final int seconds;
}

class PlatformUsageDay {
  const PlatformUsageDay(this.day, this.seconds);

  final String day;
  final int seconds;
}

class PlatformUsageHour {
  const PlatformUsageHour(this.hour, this.seconds);

  final int hour;
  final int seconds;

  String get label {
    final start = hour.toString().padLeft(2, '0');
    final end = ((hour + 1) % 24).toString().padLeft(2, '0');
    return '$start:00-$end:00';
  }
}
