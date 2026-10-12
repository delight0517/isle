import 'package:hive_flutter/hive_flutter.dart';

import '../library/usage_day.dart';
import '../services/isle_user_defaults.dart';

/// 유튜브 **음성 모드** 전용 일일 한도 (일반 영상 한도와 분리 · 데이터 절약 모드)
class YoutubePodcastListenStore {
  YoutubePodcastListenStore._();

  static const _boxName = 'isle_youtube_podcast_listen';
  static const _dayKey = 'day';
  static const _secondsKey = 'seconds_used';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('YoutubePodcastListenStore not open');
    return b;
  }

  static bool get isOpen => _box?.isOpen ?? false;

  static bool get isEnabled => IsleUserDefaults.youtubePodcastLimitEnabled;

  static int get limitSeconds =>
      IsleUserDefaults.youtubePodcastDailyLimitMinutes * 60;

  static String _todayKey() => UsageDay.key();

  static void _ensureToday() {
    final today = _todayKey();
    if (box.get(_dayKey) != today) {
      box.put(_dayKey, today);
      box.put(_secondsKey, '0');
    }
  }

  static int get secondsUsedToday {
    _ensureToday();
    return int.tryParse(box.get(_secondsKey) ?? '') ?? 0;
  }

  static int get secondsRemaining =>
      (limitSeconds - secondsUsedToday).clamp(0, limitSeconds);

  static bool get isLimitReached =>
      isEnabled && secondsUsedToday >= limitSeconds;

  static bool get shouldCountListenTime =>
      isEnabled && !isLimitReached;

  static void addSeconds(int seconds) {
    if (seconds <= 0 || !shouldCountListenTime) return;
    _ensureToday();
    box.put(_secondsKey, '${secondsUsedToday + seconds}');
  }

  static String formatStatusLine() {
    if (!isEnabled) return '음성 한도 꺼짐';
    final used = secondsUsedToday ~/ 60;
    final cap = limitSeconds ~/ 60;
    final remain = secondsRemaining ~/ 60;
    if (isLimitReached) return '오늘 음성 ${cap}분 한도 도달';
    return '음성 $used/$cap분 · ${remain}분 남음';
  }
}
