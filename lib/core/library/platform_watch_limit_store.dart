import 'package:hive_flutter/hive_flutter.dart';

import 'usage_day.dart';
import '../block_schedule/schedule_edit_guard.dart';
import '../services/isle_user_defaults.dart';
import '../usage_budget/usage_budget_models.dart';
import '../usage_budget/usage_budget_store.dart';
import '../youtube/youtube_usage_lock.dart';
import '../youtube/youtube_watch_timer_store.dart';

/// youtube · instagram · brunch — 일일 체류 한도 (WebView 열림 시 1초 tick)
///
/// Instagram DM([PlatformWatchId.instagramDm])은 한도 없음 — 피드·릴스만 [instagram] 카운트.
enum PlatformWatchId { youtube, instagram, instagramDm, brunch }

class PlatformWatchLimitStore {
  PlatformWatchLimitStore._();

  static const _boxName = 'isle_platform_watch_limits';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
    await YoutubeWatchTimerStore.ensureOpen();
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen)
      throw StateError('PlatformWatchLimitStore not open');
    return b;
  }

  static String _todayKey() => UsageDay.key();

  static void _ensureToday(PlatformWatchId id) {
    final dayK = '${id.name}_day';
    final secK = '${id.name}_seconds';
    final today = _todayKey();
    if (box.get(dayK) != today) {
      box.put(dayK, today);
      box.put(secK, '0');
    }
  }

  /// DM·유튜브 뮤직(음성)처럼 시간 한도를 두지 않는 모드
  static bool isAlwaysUnlimited(PlatformWatchId id) =>
      id == PlatformWatchId.instagramDm;

  static String? budgetTargetFor(PlatformWatchId id) {
    switch (id) {
      case PlatformWatchId.youtube:
        return UsageBudgetTarget.youtube;
      case PlatformWatchId.instagram:
        return UsageBudgetTarget.instagram;
      case PlatformWatchId.brunch:
        return UsageBudgetTarget.brunch;
      case PlatformWatchId.instagramDm:
        return null;
    }
  }

  static bool isEnabled(PlatformWatchId id) {
    if (isAlwaysUnlimited(id)) return false;
    final budgetTarget = budgetTargetFor(id);
    if (budgetTarget != null && UsageBudgetStore.isEnabled(budgetTarget)) {
      return true;
    }
    switch (id) {
      case PlatformWatchId.youtube:
        return YoutubeWatchTimerStore.isEnabled;
      case PlatformWatchId.instagram:
        return IsleUserDefaults.instagramDailyLimitEnabled;
      case PlatformWatchId.instagramDm:
        return false;
      case PlatformWatchId.brunch:
        return IsleUserDefaults.brunchDailyLimitEnabled;
    }
  }

  /// YouTube 한도 변경 가능 여부 (타임락 · 한도 도달 · 스케줄 잠금)
  static bool canChangeLimit({
    required PlatformWatchId id,
    required int newMinutes,
    required bool newEnabled,
  }) {
    if (id != PlatformWatchId.youtube) return true;
    if (!ScheduleEditGuard.canChangeDailyWatchLimit()) return false;
    final current = limitMinutes(id);
    final enabled = isEnabled(id);
    if (isLimitReached(id) &&
        !ScheduleEditGuard.canChangeDailyWatchLimitWhenLimitReached()) {
      if (newMinutes != current || newEnabled != enabled) return false;
    }
    return YoutubeUsageLock.canApplyChange(
      currentMinutes: current,
      newMinutes: newMinutes,
      currentlyEnabled: enabled,
      newEnabled: newEnabled,
    );
  }

  static Future<void> setEnabled(PlatformWatchId id, bool v) async {
    if (!canChangeLimit(id: id, newMinutes: limitMinutes(id), newEnabled: v)) {
      return;
    }
    switch (id) {
      case PlatformWatchId.youtube:
        if (YoutubeWatchTimerStore.usesInterval) {
          await IsleUserDefaults.setYoutubeIntervalLimitEnabled(v);
        } else {
          await IsleUserDefaults.setYoutubeDailyLimitEnabled(v);
        }
      case PlatformWatchId.instagram:
        await IsleUserDefaults.setInstagramDailyLimitEnabled(v);
      case PlatformWatchId.instagramDm:
        return;
      case PlatformWatchId.brunch:
        await IsleUserDefaults.setBrunchDailyLimitEnabled(v);
    }
  }

  static int limitMinutes(PlatformWatchId id) {
    switch (id) {
      case PlatformWatchId.youtube:
        return YoutubeWatchTimerStore.limitSeconds ~/ 60;
      case PlatformWatchId.instagram:
        final budget = UsageBudgetStore.policyFor(UsageBudgetTarget.instagram);
        if (budget != null && budget.enabled) return budget.dailyCapMinutes;
        return IsleUserDefaults.instagramDailyLimitMinutes;
      case PlatformWatchId.instagramDm:
        return IsleUserDefaults.instagramDmDailyLimitMinutes;
      case PlatformWatchId.brunch:
        final budget = UsageBudgetStore.policyFor(UsageBudgetTarget.brunch);
        if (budget != null && budget.enabled) return budget.dailyCapMinutes;
        return IsleUserDefaults.brunchDailyLimitMinutes;
    }
  }

  static Future<void> setLimitMinutes(PlatformWatchId id, int minutes) async {
    final m = minutes.clamp(5, 480);
    if (!canChangeLimit(id: id, newMinutes: m, newEnabled: isEnabled(id))) {
      return;
    }
    switch (id) {
      case PlatformWatchId.youtube:
        if (YoutubeWatchTimerStore.usesInterval) {
          await IsleUserDefaults.setYoutubeIntervalAllowMinutes(
              m.clamp(1, 120));
        } else {
          await IsleUserDefaults.setYoutubeDailyLimitMinutes(m);
        }
      case PlatformWatchId.instagram:
        await IsleUserDefaults.setInstagramDailyLimitMinutes(m);
      case PlatformWatchId.instagramDm:
        return;
      case PlatformWatchId.brunch:
        await IsleUserDefaults.setBrunchDailyLimitMinutes(m);
    }
  }

  static int limitSeconds(PlatformWatchId id) => limitMinutes(id) * 60;

  static int secondsUsedToday(PlatformWatchId id) {
    final budgetTarget = budgetTargetFor(id);
    if (budgetTarget != null) {
      // 정규화된 snapshot 사용 — 날짜 롤오버 시 어제값 노출 방지 (secondsRemaining와 동일 소스)
      final snap = UsageBudgetStore.snapshot(budgetTarget);
      if (snap != null) return snap.ledger.usedSecondsToday;
    }
    if (id == PlatformWatchId.youtube) {
      return YoutubeWatchTimerStore.secondsUsed;
    }
    _ensureToday(id);
    return int.tryParse(box.get('${id.name}_seconds') ?? '') ?? 0;
  }

  static int secondsRemaining(PlatformWatchId id) {
    final budgetTarget = budgetTargetFor(id);
    if (budgetTarget != null) {
      final snap = UsageBudgetStore.snapshot(budgetTarget);
      if (snap != null) return snap.dailyRemainingSeconds;
    }
    if (!isEnabled(id)) return limitSeconds(id);
    return (limitSeconds(id) - secondsUsedToday(id)).clamp(0, limitSeconds(id));
  }

  static bool isLimitReached(PlatformWatchId id) {
    if (!isEnabled(id)) return false;
    final budgetTarget = budgetTargetFor(id);
    if (budgetTarget != null && UsageBudgetStore.isEnabled(budgetTarget)) {
      return UsageBudgetStore.isLimitReached(budgetTarget);
    }
    if (id == PlatformWatchId.youtube)
      return YoutubeWatchTimerStore.isLimitReached;
    return secondsUsedToday(id) >= limitSeconds(id);
  }

  static void addSeconds(PlatformWatchId id, int seconds) {
    if (seconds <= 0 || isAlwaysUnlimited(id) || !isEnabled(id)) return;
    final budgetTarget = budgetTargetFor(id);
    if (budgetTarget != null && UsageBudgetStore.isEnabled(budgetTarget)) {
      UsageBudgetStore.addSeconds(budgetTarget, seconds);
      return;
    }
    if (id == PlatformWatchId.youtube) {
      YoutubeWatchTimerStore.addSeconds(seconds);
      return;
    }
    _ensureToday(id);
    final next = secondsUsedToday(id) + seconds;
    box.put('${id.name}_seconds', next.toString());
  }

  static String label(PlatformWatchId id) {
    switch (id) {
      case PlatformWatchId.youtube:
        return 'YouTube';
      case PlatformWatchId.instagram:
        return 'Instagram';
      case PlatformWatchId.instagramDm:
        return 'Instagram DM';
      case PlatformWatchId.brunch:
        return 'Brunch';
    }
  }

  static PlatformWatchId? fromExplorerSiteName(String name) {
    switch (name) {
      case 'youtube':
        return PlatformWatchId.youtube;
      case 'instagram':
        return PlatformWatchId.instagram;
      case 'instagram_dm':
        return PlatformWatchId.instagramDm;
      case 'brunch':
        return PlatformWatchId.brunch;
      default:
        return null;
    }
  }

  static String formatRemainChip(PlatformWatchId id) {
    if (isAlwaysUnlimited(id)) return '무제한';
    if (!isEnabled(id)) return '한도 끔';
    final remain = secondsRemaining(id);
    if (isLimitReached(id)) return '한도 도달';
    final m = remain ~/ 60;
    if (m >= 60) return '${m ~/ 60}h ${m % 60}m';
    if (m > 0) return '${m}m';
    return '${remain}s';
  }
}
