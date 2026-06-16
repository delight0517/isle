import 'models/block_schedule.dart';
import 'schedule_edit_guard.dart';

/// JSON 가져오기 — 설정 잠금(커밋먼트) 우회 방지
class ScheduleImportGuard {
  ScheduleImportGuard._();

  /// 잠금 중인 스케줄은 enabled·locked·슬롯·도메인 등 핵심 필드를 덮어쓰지 않음
  static BlockSchedule mergeIncoming({
    required BlockSchedule? existing,
    required BlockSchedule incoming,
  }) {
    if (existing == null) return incoming;
    if (!ScheduleEditGuard.isCommitmentLocked(existing)) return incoming;
    return incoming.copyWith(
      enabled: existing.enabled,
      locked: existing.locked,
      lockCooldownMinutes: existing.lockCooldownMinutes,
      unlockStartedAtMs: existing.unlockStartedAtMs,
      unlockUntilMs: existing.unlockUntilMs,
      slots: existing.slots,
      domains: existing.domains,
      enforcementMode: existing.enforcementMode,
    );
  }

  static int countProtected(List<BlockSchedule> existing, List<BlockSchedule> incoming) {
    var n = 0;
    for (final inc in incoming) {
      final ex = existing.where((e) => e.id == inc.id).firstOrNull;
      if (ex != null && ScheduleEditGuard.isCommitmentLocked(ex)) n++;
    }
    return n;
  }
}
