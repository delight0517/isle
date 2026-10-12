import 'package:hive_flutter/hive_flutter.dart';

import '../library/usage_day.dart';
import '../services/isle_user_defaults.dart';

/// 유튜브 주간(월~일) 누적 시청 초 — 요일별/영구/"이번주만" 총량 한도의
/// 실제 소진량을 추적한다. 일일 카운터([YoutubeWatchTimerStore])와 별개로
/// 주가 바뀌면(월요일 자정) 리셋된다.
class YoutubeWeeklyUsageStore {
  YoutubeWeeklyUsageStore._();

  static const _boxName = 'isle_youtube_weekly_usage';
  static const _weekKeyKey = 'week_key';
  static const _secondsKey = 'seconds_used';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('YoutubeWeeklyUsageStore not open');
    }
    return b;
  }

  static void _ensureThisWeek() {
    final currentWeek = UsageDay.weekKey();
    if (box.get(_weekKeyKey) != currentWeek) {
      box.put(_weekKeyKey, currentWeek);
      box.put(_secondsKey, '0');
    }
  }

  static int get secondsUsedThisWeek {
    _ensureThisWeek();
    return int.tryParse(box.get(_secondsKey) ?? '') ?? 0;
  }

  static void addSeconds(int seconds) {
    if (seconds <= 0) return;
    _ensureThisWeek();
    final next = secondsUsedThisWeek + seconds;
    box.put(_secondsKey, '$next');
  }

  /// 지금 적용 중인 주간 한도(분) — "이번주만" 임시 한도가 이번 주에 여전히
  /// 유효하면 그게 우선, 아니면 영구 주간 한도(꺼져 있으면 null).
  static int? get effectiveWeeklyLimitMinutes {
    final tempMinutes = IsleUserDefaults.youtubeWeeklyLimitTempMinutes;
    final tempWeek = IsleUserDefaults.youtubeWeeklyLimitTempWeek;
    if (tempMinutes != null && tempWeek == UsageDay.weekKey()) {
      return tempMinutes;
    }
    final permanent = IsleUserDefaults.youtubeWeeklyLimitMinutes;
    return permanent > 0 ? permanent : null;
  }

  static int? get secondsRemaining {
    final limitMinutes = effectiveWeeklyLimitMinutes;
    if (limitMinutes == null) return null;
    return (limitMinutes * 60 - secondsUsedThisWeek).clamp(0, 1 << 31);
  }

  static bool get isLimitReached {
    final remaining = secondsRemaining;
    return remaining != null && remaining <= 0;
  }
}
