import '../services/trusted_time_guard.dart';
import 'block_schedule_store.dart';

/// 예약 스케줄("여행 동안" 류, 2026-07-20 신설) — 특정 미래 시각에 자동으로
/// 켜지고, 정해둔 종료 시각에 자동으로 꺼지는 스케줄을 처리한다.
///
/// 4vpn의 `scheduledActivationAt`/`autoDisableAt`(TrashService) 패턴을 그대로
/// 이식 — 시작·종료 둘 다 [TrustedTimeGuard.effectiveNow]를 기준으로 판정해
/// 기기 시계를 앞으로 돌려 예약을 조기 발동시키는 것도 막는다.
class ScheduleReservationService {
  ScheduleReservationService._();

  /// 앱 실행/포그라운드 복귀 시 호출 — 예약된 활성화·비활성화를 처리한다.
  /// [TrustedTimeGuard.refresh]가 먼저 끝난 뒤에 호출해야 정확하다.
  static Future<int> processDue() async {
    final now = TrustedTimeGuard.effectiveNow();
    final list = BlockScheduleStore.loadAll();
    var changed = false;
    var processed = 0;

    for (var i = 0; i < list.length; i++) {
      final s = list[i];

      final activationAt = s.scheduledActivationAtMs;
      if (activationAt != null &&
          !s.enabled &&
          now.millisecondsSinceEpoch >= activationAt) {
        list[i] = list[i].copyWith(
          enabled: true,
          clearScheduledActivation: true,
        );
        changed = true;
        processed++;
        continue;
      }

      final deactivationAt = s.scheduledDeactivationAtMs;
      if (deactivationAt != null &&
          s.enabled &&
          now.millisecondsSinceEpoch >= deactivationAt) {
        list[i] = list[i].copyWith(
          enabled: false,
          clearScheduledDeactivation: true,
          reservationLocked: false,
        );
        changed = true;
        processed++;
      }
    }

    if (changed) {
      await BlockScheduleStore.saveAll(list);
    }
    return processed;
  }
}
