import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_user_defaults.dart';

/// 유튜브 시청 시간 — WebView가 켜져 있을 때만 누적 [Volt: pause 시 세션 종료]
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
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('YoutubeWatchTimerStore not open');
    return b;
  }

  static bool get usesInterval => IsleUserDefaults.youtubeLimitUsesInterval;

  static bool get isEnabled => usesInterval
      ? IsleUserDefaults.youtubeIntervalLimitEnabled
      : IsleUserDefaults.youtubeDailyLimitEnabled;

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

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

  static int get dailyLimitSeconds => IsleUserDefaults.youtubeDailyLimitMinutes * 60;

  static int get intervalLimitSeconds =>
      IsleUserDefaults.youtubeIntervalAllowMinutes * 60;

  static int get limitSeconds =>
      usesInterval ? intervalLimitSeconds : dailyLimitSeconds;

  static int get secondsUsedToday {
    _ensureToday();
    return int.tryParse(box.get(_secondsKey) ?? '') ?? 0;
  }

  static int get secondsUsedInWindow {
    _ensureIntervalWindow();
    return int.tryParse(box.get(_intervalSecondsKey) ?? '') ?? 0;
  }

  static int get secondsUsed => usesInterval ? secondsUsedInWindow : secondsUsedToday;

  static int get secondsRemaining =>
      (limitSeconds - secondsUsed).clamp(0, limitSeconds);

  static bool get isLimitReached =>
      isEnabled && secondsUsed >= limitSeconds;

  static void addSeconds(int seconds) {
    if (seconds <= 0 || !isEnabled) return;
    if (usesInterval) {
      _ensureIntervalWindow();
      final next = secondsUsedInWindow + seconds;
      box.put(_intervalSecondsKey, next.toString());
      return;
    }
    _ensureToday();
    final next = secondsUsedToday + seconds;
    box.put(_secondsKey, next.toString());
  }

  static Duration timeUntilReset() =>
      usesInterval ? timeUntilIntervalWindowReset() : timeUntilDailyReset();

  static Duration timeUntilDailyReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

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
