import 'models/block_schedule.dart';
import 'schedule_edit_guard.dart';
import 'schedule_import_guard.dart';

/// 스케줄 Hive 저장 — UI·AI·JSON 가져오기 공통 타임락 우회 방지
class SchedulePersistGuard {
  SchedulePersistGuard._();

  static BlockSchedule sanitizeUpsert({
    required BlockSchedule? existing,
    required BlockSchedule incoming,
  }) =>
      ScheduleImportGuard.mergeIncoming(existing: existing, incoming: incoming);

  static bool canDelete(BlockSchedule schedule) =>
      !ScheduleEditGuard.isCommitmentLocked(schedule);
}
