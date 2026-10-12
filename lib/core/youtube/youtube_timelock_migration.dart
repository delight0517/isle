import '../block_schedule/block_schedule_store.dart';
import '../block_schedule/models/schedule_app_target_entry.dart';
import '../block_schedule/schedule_app_targets_service.dart';
import '../block_schedule/schedule_app_targets_store.dart';
import '../services/isle_app_log_service.dart';
import 'youtube_timelock_service.dart';

/// 타임락 스케줄 — `blockIsleInApp`+도메인 대신 **③ Isle 유튜브** 타깃과 동기화
class YoutubeTimelockMigration {
  YoutubeTimelockMigration._();

  static Future<void> syncTargetsIfNeeded() async {
    if (!YoutubeTimelockService.isActive) return;
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    final schedule = BlockScheduleStore.loadAll()
        .where((s) => s.id == YoutubeTimelockService.timelockScheduleId)
        .firstOrNull;
    if (schedule == null || !schedule.enabled) return;

    var entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(schedule.id),
    );
    final yt = entries.where((e) => e.targetId == 'isle_youtube').firstOrNull;
    if (yt != null && yt.blockInSlot) return;

    entries = entries
        .map(
          (e) => e.targetId == 'isle_youtube' ? e.copyWith(blockInSlot: true) : e,
        )
        .toList();
    if (!entries.any((e) => e.targetId == 'isle_youtube')) {
      entries = [...entries, const ScheduleAppTargetEntry(targetId: 'isle_youtube', blockInSlot: true)];
    }

    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: schedule.id,
      entries: entries,
      schedule: schedule,
    );
    IsleAppLogService.log('YoutubeTimelock: isle_youtube 타깃 동기화');
  }
}
