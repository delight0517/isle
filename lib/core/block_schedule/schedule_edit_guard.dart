import '../services/trusted_time_guard.dart';
import 'models/block_schedule.dart';
import 'schedule_active_service.dart';
import 'schedule_lock_phase.dart';
import 'schedule_lock_service.dart';

/// 스케줄·한도 UI 편집 가능 여부
///
/// - **설정 잠금(커밋먼트)** 켜짐 → 카운트다운 후 5분 편집 창에서만 전체 수정
/// - 잠금 꺼짐 + 스케줄 활성 → 앱·대상·시간표 편집 가능 (시간은 [ScheduleSlotEditPolicy] ±1h)
/// - **예약 잠금(reservationLocked)** 켜짐 → 예약 종료 시각 전까지는 대기·해제
///   경로 자체가 없다(일반 커밋먼트 락과 달리 카운트다운으로도 못 품) —
///   4vpn의 `lockProtected`와 동일한 의도, 사용자가 명시적으로 "예약은 못
///   풀리게 해줘"라고 요청한 경우에만 켜진다(2026-07-20).
class ScheduleEditGuard {
  ScheduleEditGuard._();

  /// 설정 잠금이 편집을 막는 상태인지
  static bool isCommitmentLocked(BlockSchedule schedule, [DateTime? at]) {
    if (schedule.reservationLocked) {
      final deactivationAt = schedule.scheduledDeactivationAtMs;
      final now = at ?? TrustedTimeGuard.effectiveNow();
      // 종료 시각을 이미 지났으면(reconciliation이 아직 안 돌았어도) 더는
      // 막지 않는다 — processDue()가 곧 정리한다.
      if (deactivationAt == null || now.millisecondsSinceEpoch < deactivationAt) {
        return true;
      }
    }
    if (!schedule.locked) return false;
    return ScheduleLockService.phase(schedule, at) != ScheduleLockPhase.editWindow;
  }

  static bool canEditScheduleFields(BlockSchedule schedule, [DateTime? at]) {
    if (isCommitmentLocked(schedule, at)) return false;
    return true;
  }

  static bool canEditAppsAndTargets(BlockSchedule schedule, [DateTime? at]) =>
      canEditScheduleFields(schedule, at);

  /// 잠금 중에도 앱 추가·제거 예약 가능
  static bool canQueueTargetEdits(BlockSchedule schedule) => schedule.id.isNotEmpty;

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
