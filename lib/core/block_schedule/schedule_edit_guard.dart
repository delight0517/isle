import 'models/block_schedule.dart';
import 'schedule_active_service.dart';
import 'schedule_lock_phase.dart';
import 'schedule_lock_service.dart';

/// 스케줄·한도 UI 편집 가능 여부
///
/// - **설정 잠금(커밋먼트)** 켜짐 → 카운트다운 후 5분 편집 창에서만 전체 수정
/// - 잠금 꺼짐 + 스케줄 활성 → 앱·대상·시간표 편집 가능 (시간은 [ScheduleSlotEditPolicy] ±1h)
class ScheduleEditGuard {
  ScheduleEditGuard._();

  /// 설정 잠금이 편집을 막는 상태인지
  static bool isCommitmentLocked(BlockSchedule schedule, [DateTime? at]) {
    if (!schedule.locked) return false;
    return ScheduleLockService.phase(schedule, at) != ScheduleLockPhase.editWindow;
  }

  static bool canEditScheduleFields(BlockSchedule schedule, [DateTime? at]) {
    if (isCommitmentLocked(schedule, at)) return false;
    return true;
  }

  static bool canEditAppsAndTargets(BlockSchedule schedule, [DateTime? at]) =>
      canEditScheduleFields(schedule, at);

  static bool canEditCooldownMinutes(BlockSchedule schedule) =>
      !schedule.locked && canEditScheduleFields(schedule);

  static bool canToggleCommitmentLock(BlockSchedule schedule, bool newLocked) {
    if (!newLocked && schedule.locked) {
      return ScheduleLockService.phase(schedule) == ScheduleLockPhase.editWindow;
    }
    return canEditScheduleFields(schedule);
  }

  static bool canToggleScheduleEnabled(BlockSchedule schedule, [DateTime? at]) =>
      canEditScheduleFields(schedule, at);

  /// 전체 스케줄 차단 끄기 — 활성+커밋먼트 잠금 스케줄이 있으면 불가
  static bool canDisableMasterScheduleLock() {
    for (final s in ScheduleActiveService.activeSchedulesNow()) {
      if (isCommitmentLocked(s)) return false;
    }
    return true;
  }

  static bool canChangeDailyWatchLimit() {
    if (ScheduleActiveService.isYoutubeWebViewBlockedNow()) return false;
    return true;
  }

  static bool canChangeDailyWatchLimitWhenLimitReached() => false;
}
