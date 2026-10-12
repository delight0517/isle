import 'package:hive_flutter/hive_flutter.dart';

import '../library/usage_day.dart';
import '../services/isle_user_defaults.dart';
import '../services/notification_service.dart';
import '../usage_budget/usage_budget_models.dart';
import '../usage_budget/usage_budget_store.dart';
import 'youtube_weekly_usage_store.dart';

/// 30/50/70/100% 중, [beforePercent]에서 [afterPercent]로 사용량이 늘면서
/// 새로 넘은(=아직 그날 알림 안 보낸) 임계값만 골라 반환 — 실제 알림 전송과
/// 분리한 순수 함수라 유닛테스트 가능(2026-07-13 신규).
List<int> newlyCrossedUsageThresholds({
  required double beforePercent,
  required double afterPercent,
  required Set<int> alreadyNotifiedToday,
}) {
  const thresholds = [30, 50, 70, 100];
  return thresholds
      .where((t) =>
          beforePercent < t &&
          afterPercent >= t &&
          !alreadyNotifiedToday.contains(t))
      .toList();
}

/// 유튜브 시청 시간 — 포그라운드에서 실제 영상이 재생 중일 때만 누적.
///
/// - **일일**: 자정 리셋
/// - **주기**: N시간 창마다 M분만 허용 (예: 3시간마다 20분)
class YoutubeWatchTimerStore {
  YoutubeWatchTimerStore._();

  static const _boxName = 'isle_youtube_timer';
  static const _dayKey = 'day_yyyy_mm_dd';
  static const _secondsKey = 'seconds_used';
  static const _intervalStartKey = 'interval_window_start_ms';
  static const _intervalSecondsKey = 'interval_seconds_used';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
    await YoutubeWeeklyUsageStore.ensureOpen();
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen)
      throw StateError('YoutubeWatchTimerStore not open');
    return b;
  }

  static bool get usesInterval => IsleUserDefaults.youtubeLimitUsesInterval;

  static bool get isEnabled => usesInterval
      ? IsleUserDefaults.youtubeIntervalLimitEnabled
      : IsleUserDefaults.youtubeDailyLimitEnabled;

  static bool get usesBudget =>
      UsageBudgetStore.isEnabled(UsageBudgetTarget.youtube);

  static String _todayKey() => UsageDay.key();

  static void _ensureToday() {
    final today = _todayKey();
    if (box.get(_dayKey) != today) {
      box.put(_dayKey, today);
      box.put(_secondsKey, '0');
    }
  }

  static void _ensureIntervalWindow() {
    final windowMin = IsleUserDefaults.youtubeIntervalWindowMinutes;
    final now = DateTime.now().millisecondsSinceEpoch;
    final raw = box.get(_intervalStartKey);
    if (raw == null) {
      box.put(_intervalStartKey, '$now');
      box.put(_intervalSecondsKey, '0');
      return;
    }
    final start = int.tryParse(raw) ?? now;
    final elapsedMin = (now - start) ~/ 60000;
    if (elapsedMin >= windowMin) {
      box.put(_intervalStartKey, '$now');
      box.put(_intervalSecondsKey, '0');
    }
  }

  /// 오늘 요일에 별도 오버라이드("일요일엔 하루 7시간")가 있으면 그걸,
  /// 없으면 평소 하루 총량을 쓴다.
  static int get dailyLimitSeconds {
    final todayWeekday = DateTime.now().weekday;
    final override = IsleUserDefaults.youtubeWeekdayLimitOverrides[todayWeekday];
    return (override ?? IsleUserDefaults.youtubeDailyLimitMinutes) * 60;
  }

  static int get intervalLimitSeconds =>
      IsleUserDefaults.youtubeIntervalAllowMinutes * 60;

  static int get limitSeconds => usesBudget
      ? (UsageBudgetStore.policyFor(UsageBudgetTarget.youtube)
              ?.dailyCapSeconds ??
          dailyLimitSeconds)
      : usesInterval
          ? intervalLimitSeconds
          : dailyLimitSeconds;

  /// 타이머 박스에 저장된 원시 오늘 사용 초 (예산모드 무관 · 내부 write/preserve 전용).
  static int get _rawSecondsUsedToday {
    _ensureToday();
    return int.tryParse(box.get(_secondsKey) ?? '') ?? 0;
  }

  /// 오늘 사용 초 — 예산(충전식) 모드면 예산 원장을 단일 소스로 사용.
  /// limitSeconds/secondsRemaining/isLimitReached와 동일 소스라 "사용/한도"가 어긋나지 않는다.
  static int get secondsUsedToday {
    if (usesBudget) {
      final snap = UsageBudgetStore.snapshot(UsageBudgetTarget.youtube);
      if (snap != null) return snap.ledger.usedSecondsToday;
    }
    return _rawSecondsUsedToday;
  }

  static int get secondsUsedInWindow {
    _ensureIntervalWindow();
    return int.tryParse(box.get(_intervalSecondsKey) ?? '') ?? 0;
  }

  static Future<void> preserveTodayUsageAtLeast(int seconds) async {
    if (seconds <= 0) return;
    _ensureToday();
    final next = seconds.clamp(_rawSecondsUsedToday, 24 * 60 * 60).toInt();
    await box.put(_secondsKey, next.toString());
  }

  static Future<void> preserveCurrentWindowUsageAtLeast(int seconds) async {
    if (seconds <= 0) return;
    _ensureIntervalWindow();
    final next = seconds.clamp(secondsUsedInWindow, intervalLimitSeconds).toInt();
    await box.put(_intervalSecondsKey, next.toString());
  }

  static int get secondsUsed => usesBudget
      ? secondsUsedToday
      : (usesInterval ? secondsUsedInWindow : _rawSecondsUsedToday);

  static int get _baseSecondsRemaining => usesBudget
      ? (UsageBudgetStore.snapshot(UsageBudgetTarget.youtube)
              ?.dailyRemainingSeconds ??
          limitSeconds)
      : (limitSeconds - secondsUsed).clamp(0, limitSeconds);

  /// 일일(또는 예산) 한도와 주간 총량("이번주 유튜브 10시간" 등) 중 더
  /// 빡빡한 쪽을 실제 잔여 시간으로 쓴다 — 둘 다 켜져 있으면 먼저 닿는
  /// 쪽에서 막혀야 한다.
  static int get secondsRemaining {
    final base = _baseSecondsRemaining;
    final weeklyRemaining = YoutubeWeeklyUsageStore.secondsRemaining;
    if (weeklyRemaining == null) return base;
    return base < weeklyRemaining ? base : weeklyRemaining;
  }

  static bool get isLimitReached {
    final baseReached = usesBudget
        ? UsageBudgetStore.isLimitReached(UsageBudgetTarget.youtube)
        : isEnabled && secondsUsed >= limitSeconds;
    return baseReached || YoutubeWeeklyUsageStore.isLimitReached;
  }

  /// 지금 기준 "하루 한도 대비 %"와 "주간 한도 대비 %" 중 더 급한(높은) 쪽 —
  /// 둘 다 켜져 있으면 더 빨리 소진되는 쪽 기준으로 알림을 보낸다.
  static double _effectiveUsedPercent() {
    final dailyPercent =
        isEnabled && limitSeconds > 0 ? (secondsUsed / limitSeconds * 100) : 0.0;
    final weeklyLimitMin = YoutubeWeeklyUsageStore.effectiveWeeklyLimitMinutes;
    final weeklyPercent = weeklyLimitMin != null && weeklyLimitMin > 0
        ? (YoutubeWeeklyUsageStore.secondsUsedThisWeek / (weeklyLimitMin * 60) * 100)
        : 0.0;
    return dailyPercent > weeklyPercent ? dailyPercent : weeklyPercent;
  }

  static void addSeconds(int seconds) {
    if (seconds <= 0) return;
    final beforePercent = _effectiveUsedPercent();
    YoutubeWeeklyUsageStore.addSeconds(seconds);
    _addSecondsRaw(seconds);
    final afterPercent = _effectiveUsedPercent();
    final crossed = newlyCrossedUsageThresholds(
      beforePercent: beforePercent,
      afterPercent: afterPercent,
      alreadyNotifiedToday: IsleUserDefaults.youtubeNotifiedThresholdsToday,
    );
    for (final threshold in crossed) {
      IsleUserDefaults.addYoutubeNotifiedThresholdToday(threshold);
      // 알림 전송은 fire-and-forget — addSeconds는 매초 tick에서 동기 호출됨.
      // ignore: discarded_futures
      NotificationService.notifyYoutubeUsageThreshold(threshold);
    }
  }

  static void _addSecondsRaw(int seconds) {
    if (usesBudget) {
      UsageBudgetStore.addSeconds(UsageBudgetTarget.youtube, seconds);
      return;
    }
    if (!isEnabled) return;
    if (usesInterval) {
      _ensureIntervalWindow();
      final next = secondsUsedInWindow + seconds;
      box.put(_intervalSecondsKey, next.toString());
      return;
    }
    _ensureToday();
    final next = _rawSecondsUsedToday + seconds;
    box.put(_secondsKey, next.toString());
  }

  static Duration timeUntilReset() {
    if (usesBudget) {
      final until =
          UsageBudgetStore.snapshot(UsageBudgetTarget.youtube)?.lockedUntil;
      if (until != null) {
        final left = until.difference(DateTime.now());
        return left.isNegative ? Duration.zero : left;
      }
    }
    return usesInterval ? timeUntilIntervalWindowReset() : timeUntilDailyReset();
  }

  static Duration timeUntilDailyReset() => UsageDay.timeUntilMidnight();

  static Duration timeUntilIntervalWindowReset() {
    _ensureIntervalWindow();
    final start = int.tryParse(box.get(_intervalStartKey) ?? '') ??
        DateTime.now().millisecondsSinceEpoch;
    final windowMs = IsleUserDefaults.youtubeIntervalWindowMinutes * 60000;
    final end = start + windowMs;
    final now = DateTime.now().millisecondsSinceEpoch;
    return Duration(milliseconds: (end - now).clamp(0, windowMs));
  }

  static String formatStatusLine() {
    if (usesBudget) {
      return UsageBudgetStore.formatStatusLine(UsageBudgetTarget.youtube);
    }
    if (!isEnabled) return '한도 꺼짐';
    final used = secondsUsed ~/ 60;
    final cap = limitSeconds ~/ 60;
    final remain = secondsRemaining ~/ 60;
    if (usesInterval) {
      final w = IsleUserDefaults.youtubeIntervalWindowMinutes;
      final h = w ~/ 60;
      final wLabel = h >= 1 ? '${h}시간' : '${w}분';
      if (isLimitReached) {
        final wait = timeUntilIntervalWindowReset();
        final wm = wait.inMinutes;
        return '$wLabel마다 ${cap}분 · 한도 도달 · ${wm}분 후 다시';
      }
      return '$wLabel마다 ${cap}분 · ${used}분 사용 · ${remain}분 남음';
    }
    if (isLimitReached) return '오늘 ${cap}분 한도 도달';
    return '오늘 ${used}분 / ${cap}분 · ${remain}분 남음';
  }
}
