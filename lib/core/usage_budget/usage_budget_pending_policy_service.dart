import 'dart:math';

import '../block_schedule/block_schedule_store.dart';
import '../block_schedule/models/block_schedule.dart';
import '../block_schedule/schedule_active_service.dart';
import '../block_schedule/schedule_app_targets_store.dart';
import '../block_schedule/schedule_edit_guard.dart';
import '../block_schedule/schedule_lock_phase.dart';
import '../block_schedule/schedule_lock_service.dart';
import '../library/platform_watch_limit_store.dart';
import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import '../youtube/youtube_usage_lock.dart';
import 'usage_budget_engine.dart';
import 'usage_budget_models.dart';
import 'usage_budget_store.dart';

class UsageBudgetPendingPolicyResult {
  const UsageBudgetPendingPolicyResult({
    required this.pending,
    required this.remaining,
  });

  final UsageBudgetPendingPolicy pending;
  final Duration remaining;
}

/// 타임락 중 한도 모드 변경을 예약하고, 대기 완료 후 자동 적용한다.
class UsageBudgetPendingPolicyService {
  UsageBudgetPendingPolicyService._();

  static Future<UsageBudgetPendingPolicyResult> scheduleYoutubePolicy(
    UsageBudgetPolicy policy, {
    required int carryUsedSecondsToday,
  }) async {
    await _ensureOpen();
    await processDue();

    final now = DateTime.now();
    final applyAt = await _planYoutubeApplyAt(now);
    final pending = UsageBudgetPendingPolicy(
      policy: policy,
      applyAt: applyAt,
      scheduledAt: now,
      carryUsedSecondsToday: carryUsedSecondsToday,
    );
    await UsageBudgetStore.savePendingPolicy(pending);
    return UsageBudgetPendingPolicyResult(
      pending: pending,
      remaining: pending.remaining(),
    );
  }

  static Future<int> processDue() async {
    await _ensureOpen();
    await ScheduleLockService.finalizeExpiredLocks();

    final now = DateTime.now();
    var applied = 0;
    for (final pending in UsageBudgetStore.pendingPolicies()) {
      if (pending.applyAt.isAfter(now)) continue;
      if (pending.target == UsageBudgetTarget.youtube) {
        await _applyYoutubePolicy(pending);
      } else {
        await UsageBudgetStore.savePolicy(pending.policy);
      }
      await UsageBudgetStore.clearPendingPolicy(pending.target);
      applied++;
      IsleAppLogService.log(
        'Usage budget pending policy applied: ${pending.target}',
      );
    }
    return applied;
  }

  static UsageBudgetPendingPolicy? pendingFor(String target) =>
      UsageBudgetStore.pendingPolicyFor(target);

  static Future<void> cancel(String target) =>
      UsageBudgetStore.clearPendingPolicy(target);

  static Future<void> _ensureOpen() async {
    await UsageBudgetStore.ensureOpen();
    await PlatformWatchLimitStore.ensureOpen();
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
  }

  static Future<DateTime> _planYoutubeApplyAt(DateTime now) async {
    var wait = Duration.zero;

    if (YoutubeUsageLock.raiseLockEnabled &&
        !YoutubeUsageLock.unlockWindowOpen) {
      final left = YoutubeUsageLock.unlockRemaining;
      if (left != null) {
        wait = _max(wait, left);
      } else {
        await YoutubeUsageLock.startUnlockCountdown();
        wait = _max(
          wait,
          Duration(minutes: YoutubeUsageLock.unlockFreezeMinutes),
        );
      }
    }

    for (final schedule in _activeLockedYoutubeSchedules(now)) {
      final phase = ScheduleLockService.phase(schedule, now);
      if (phase == ScheduleLockPhase.countdown) {
        wait = _max(
          wait,
          ScheduleLockService.countdownRemaining(schedule, now) ??
              Duration.zero,
        );
      } else if (phase == ScheduleLockPhase.locked) {
        final updated =
            await ScheduleLockService.startUnlockCountdown(schedule.id);
        wait = _max(
          wait,
          Duration(
            minutes:
                updated?.lockCooldownMinutes ?? schedule.lockCooldownMinutes,
          ),
        );
      }
    }

    return now.add(wait);
  }

  static List<BlockSchedule> _activeLockedYoutubeSchedules(DateTime now) {
    final out = <BlockSchedule>[];
    for (final schedule in ScheduleActiveService.activeSchedulesNow(now)) {
      if (!ScheduleEditGuard.isCommitmentLocked(schedule, now)) continue;
      if (_scheduleAffectsYoutube(schedule)) out.add(schedule);
    }
    return out;
  }

  static bool _scheduleAffectsYoutube(BlockSchedule schedule) {
    if (schedule.blockIsleInApp) return true;
    if (schedule.domains.any((d) {
      final lower = d.toLowerCase();
      return lower.contains('youtube') || lower.contains('youtu.be');
    })) {
      return true;
    }
    final entries = ScheduleAppTargetsStore.loadForSchedule(schedule.id);
    return entries.any((e) =>
        e.targetId == 'isle_youtube' ||
        e.targetId == 'ios_youtube' ||
        e.targetId == 'ios_youtube_music' ||
        e.targetId == 'youtube' ||
        e.targetId == 'youtube_music');
  }

  static Future<void> _applyYoutubePolicy(
    UsageBudgetPendingPolicy pending,
  ) async {
    final currentUsed = PlatformWatchLimitStore.secondsUsedToday(
      PlatformWatchId.youtube,
    );
    final used = max(pending.carryUsedSecondsToday, currentUsed);
    await UsageBudgetStore.savePolicy(pending.policy);
    await _seedYoutubeBudgetLedger(pending.policy, used);
    await IsleUserDefaults.setYoutubeDailyLimitEnabled(false);
    await IsleUserDefaults.setYoutubeIntervalLimitEnabled(false);
    if (YoutubeUsageLock.unlockWindowOpen) {
      await YoutubeUsageLock.clearUnlockCountdown();
    }
  }

  static Future<void> _seedYoutubeBudgetLedger(
    UsageBudgetPolicy policy,
    int usedSeconds,
  ) async {
    final now = DateTime.now();
    final used = usedSeconds.clamp(0, policy.dailyCapSeconds).toInt();
    final remaining =
        (policy.dailyCapSeconds - used).clamp(0, policy.dailyCapSeconds);
    final tokens = policy.burstCapSeconds.clamp(0, remaining).toInt();
    await UsageBudgetStore.saveLedger(
      UsageBudgetTarget.youtube,
      UsageBudgetLedger(
        dayKey: UsageBudgetEngine.dayKey(now),
        usedSecondsToday: used,
        tokenSeconds: tokens,
        lastRefillAt: now,
        lockedUntil: remaining <= 0 ? UsageBudgetEngine.nextDay(now) : null,
      ),
    );
  }

  static Duration _max(Duration a, Duration b) => a >= b ? a : b;
}
