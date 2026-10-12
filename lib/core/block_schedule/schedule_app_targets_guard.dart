import 'models/block_schedule.dart';
import 'models/schedule_app_target_entry.dart';
import 'schedule_edit_guard.dart';

/// 앱별 타깃 항목(차단·나눠쓰기 한도) 저장 — 설정 잠금(커밋먼트) 중엔
/// **완화(느슨하게 만드는 변경)만** 막고 **강화는 항상 허용**한다.
///
/// **왜 필요한가(2026-07-11 실측 버그)**: 잠긴 완전 차단 스케줄에 "10분 쓰고
/// 50분 쉬게 해줘" 같은 리필 요청을 하면, 스케줄 레벨 enforcementMode는
/// 잠금 보호로 fullBlock을 유지하는데, 앱별 타깃 항목은 이 보호가 없어서
/// limitEnabled:true(리필)로 바뀌어버렸다 — 완전 차단과 리필이 동시에 저장된
/// 모순 상태. 이 가드가 그 갭을 메운다.
///
/// **완화 vs 강화 판정(사용자 확정, 2026-07-11)**: 잠긴 스케줄이라도 채팅으로
/// 즉시 조정 가능해야 한다는 기존 UX(덮어쓰기 전제)를 깨지 않기 위해, "더
/// 강하게 막는" 방향의 변경은 잠금과 무관하게 즉시 반영하고, "더 풀어주는"
/// 방향만 막는다:
/// - 완전 차단(blockInSlot) → 리필/무제한: 완화 (막음)
/// - 리필/무제한 → 완전 차단(blockInSlot): 강화 (허용)
/// - 리필 유지, 허용 비율(limitMinutes/windowMinutes)이 늘어남: 완화 (막음)
/// - 리필 유지, 허용 비율이 줄거나 같음: 강화·동일 (허용)
/// - 기존에 아무 제한도 없던 targetId에 새로 제한을 거는 것: 항상 허용
class ScheduleAppTargetsGuard {
  ScheduleAppTargetsGuard._();

  /// [old] 대비 [incoming]이 "완화"인지 — 더 많은 화면 시간을 허용하는
  /// 방향인지 판정한다.
  /// public — executor가 "이 변경이 완화인지"를 미리 알아서 예약 큐로
  /// 보낼지 판단하는 데도 재사용한다([SchedulePendingTargetService] 연동).
  static bool isRelaxation(
    ScheduleAppTargetEntry old,
    ScheduleAppTargetEntry incoming,
  ) {
    final oldFullyRestricted = old.blockInSlot;
    final newFullyRestricted = incoming.blockInSlot;
    if (oldFullyRestricted && !newFullyRestricted) return true;
    if (!oldFullyRestricted && newFullyRestricted) return false;
    if (oldFullyRestricted && newFullyRestricted) return false;

    // 둘 다 완전 차단은 아님 — limitEnabled(리필) 비교. 둘 다 제한이 아예
    // 없으면 완화가 아니고(비교 불가), 리필을 새로 켜는 것도 old가 완전
    // 무제한이었다면 오히려 강화(제한이 생김)다.
    if (!old.limitEnabled && incoming.limitEnabled) return false;
    if (old.limitEnabled && !incoming.limitEnabled) return true;
    if (!old.limitEnabled && !incoming.limitEnabled) return false;

    final oldRatio = old.windowMinutes <= 0
        ? 1.0
        : old.limitMinutes / old.windowMinutes;
    final newRatio = incoming.windowMinutes <= 0
        ? 1.0
        : incoming.limitMinutes / incoming.windowMinutes;
    return newRatio > oldRatio;
  }

  /// 잠금 중이면, 완화 방향인 targetId만 기존 값으로 되돌린다. 강화 방향
  /// 변경이나 새 targetId 추가는 잠금과 무관하게 그대로 반영한다.
  static List<ScheduleAppTargetEntry> sanitizeEntries({
    required BlockSchedule schedule,
    required List<ScheduleAppTargetEntry> existing,
    required List<ScheduleAppTargetEntry> incoming,
  }) {
    if (!ScheduleEditGuard.isCommitmentLocked(schedule)) return incoming;

    final existingById = {for (final e in existing) e.targetId: e};
    return [
      for (final inc in incoming)
        if (existingById[inc.targetId] case final old?
            when isRelaxation(old, inc))
          inc.copyWith(
            blockInSlot: old.blockInSlot,
            limitEnabled: old.limitEnabled,
            limitMinutes: old.limitMinutes,
            windowMinutes: old.windowMinutes,
          )
        else
          inc,
    ];
  }

  /// 잠금 때문에 완화 요청이 하나라도 거부됐는지 — 채팅 응답에서 "모드도 안
  /// 바뀌었다"고 알려주거나 예약을 제안할지 판단하는 데 쓴다.
  static bool wasAnyRelaxationRejected({
    required BlockSchedule schedule,
    required List<ScheduleAppTargetEntry> existing,
    required List<ScheduleAppTargetEntry> incoming,
  }) {
    if (!ScheduleEditGuard.isCommitmentLocked(schedule)) return false;
    final existingById = {for (final e in existing) e.targetId: e};
    for (final inc in incoming) {
      final old = existingById[inc.targetId];
      if (old == null) continue;
      if (isRelaxation(old, inc)) return true;
    }
    return false;
  }
}
