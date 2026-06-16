import 'youtube_schedule_lock_store.dart';
import 'youtube_watch_timer_store.dart';

enum YoutubeLockReason { schedule, dailyLimit }

/// WebView 유튜브 접근 — 일일 한도 · 스케줄의 「Isle 앱 안에서 차단」(명시 opt-in)
class YoutubeAccessGuard {
  YoutubeAccessGuard._();

  static YoutubeLockReason? activeLock([DateTime? at]) {
    if (YoutubeScheduleLockStore.isLockedNow(at)) {
      return YoutubeLockReason.schedule;
    }
    if (YoutubeWatchTimerStore.isEnabled && YoutubeWatchTimerStore.isLimitReached) {
      return YoutubeLockReason.dailyLimit;
    }
    return null;
  }

  static bool get shouldBlockWebView => activeLock() != null;

  static bool get shouldCountWatchTime {
    if (YoutubeScheduleLockStore.isLockedNow()) return false;
    if (!YoutubeWatchTimerStore.isEnabled) return false;
    if (YoutubeWatchTimerStore.isLimitReached) return false;
    return true;
  }
}
