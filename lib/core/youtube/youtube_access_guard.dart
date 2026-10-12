import '../block_schedule/schedule_target_access_guard.dart';
import '../usage_budget/usage_budget_models.dart';
import '../usage_budget/usage_budget_store.dart';
import 'youtube_schedule_lock_store.dart';
import 'youtube_watch_timer_store.dart';

enum YoutubeLockReason { schedule, scheduleLimit, dailyLimit, budget }

/// **Isle 앱 안 유튜브 시청 — 유일한 기준**
///
/// 1. 활성 스케줄에서 「Isle 유튜브」타깃 완전 차단
/// 2. 활성 스케줄의 유튜브 리필 한도(시간당 N분 등) 도달 — 여러 스케줄이
///    겹치면 가장 빡빡한 스케줄에서 먼저 막힌다(안전 라인 포함, 항상 하한선).
/// 3. 일일·주기 시청 한도(설정/챗으로 켠 전역 한도)
///
/// 위 판정은 모두 "가장 제한적인 규칙 승리"로 합쳐진다 — 어느 한 규칙이라도
/// 막으면 막힌다. (2)를 예전엔 인앱 유튜브 탭에서 아예 안 봤던 게
/// 겹친 스케줄이 "제대로 안 되는" 원인이었다(안전 라인의 시간당 10분이
/// 인앱 웹뷰엔 적용 안 됨) — 2026-07-20 수정.
///
/// Safari·도메인 쉴드·타임락·blockIsleInApp 은 **브라우저/별도 설정** — 시청 판정에 넣지 않음.
class YoutubeAccessGuard {
  YoutubeAccessGuard._();

  static YoutubeLockReason? activeLock([DateTime? at]) {
    if (YoutubeScheduleLockStore.isLockedNow(at)) {
      return YoutubeLockReason.schedule;
    }
    if (ScheduleTargetAccessGuard.isYoutubeScheduleLimitReachedNow(at)) {
      return YoutubeLockReason.scheduleLimit;
    }
    if (UsageBudgetStore.isEnabled(UsageBudgetTarget.youtube) &&
        UsageBudgetStore.isLimitReached(UsageBudgetTarget.youtube)) {
      return YoutubeLockReason.budget;
    }
    if (YoutubeWatchTimerStore.isEnabled &&
        YoutubeWatchTimerStore.isLimitReached) {
      return YoutubeLockReason.dailyLimit;
    }
    return null;
  }

  static bool get shouldBlockWebView => activeLock() != null;

  /// Isle `/youtube` 시청 가능 — 스케줄 타깃·한도만 (Safari·도메인 쉴드 제외)
  static bool get canWatchInIsleApp => activeLock() == null;

  static bool get shouldCountWatchTime {
    if (YoutubeScheduleLockStore.isLockedNow()) return false;
    // 스케줄 리필 한도에 이미 닿았으면 정지 — 전역 한도가 아직 여유 있어도.
    if (ScheduleTargetAccessGuard.isYoutubeScheduleLimitReachedNow()) {
      return false;
    }
    if (UsageBudgetStore.isEnabled(UsageBudgetTarget.youtube)) {
      return UsageBudgetStore.shouldCount(UsageBudgetTarget.youtube);
    }
    if (YoutubeWatchTimerStore.isEnabled) {
      return !YoutubeWatchTimerStore.isLimitReached;
    }
    // 전역 한도가 하나도 없어도, 활성 스케줄에 유튜브 리필 한도가 걸려 있으면
    // 그 창 사용량을 집계해야 한다(안 그러면 리필 한도가 영원히 안 참).
    return ScheduleTargetAccessGuard.hasActiveYoutubeLimitNow();
  }
}
