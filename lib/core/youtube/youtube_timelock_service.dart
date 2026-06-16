import '../block_schedule/block_schedule_enforcement_service.dart';
import '../block_schedule/block_schedule_store.dart';
import '../block_schedule/models/block_schedule.dart';
import '../block_schedule/models/schedule_slot.dart';
import '../platform/ios_screen_time_service.dart';
import '../services/isle_user_defaults.dart';
/// 타임락 방식 — Isle WebView + 스케줄(24h) + iOS Screen Time 동기화
class YoutubeTimelockService {
  YoutubeTimelockService._();

  static const timelockScheduleId = 'isle_youtube_timelock';
  static const timelockScheduleName = 'YouTube 전체 차단 (타임락)';

  static List<ScheduleSlot> get allDaySlots => [
        for (var day = 0; day < 7; day++)
          ScheduleSlot(day: day, startMinute: 0, endMinute: 24 * 60),
      ];

  static bool get isActive {
    if (!IsleUserDefaults.youtubeTimelockEnabled) return false;
    final list = BlockScheduleStore.loadAll();
    final sch = list.cast<BlockSchedule?>().firstWhere(
          (s) => s?.id == timelockScheduleId,
          orElse: () => null,
        );
    return sch != null && sch.enabled;
  }

  static Future<bool> enable() async {
    await BlockScheduleStore.ensureOpen();
    IsleUserDefaults.setYoutubeTimelockEnabled(true);
    IsleUserDefaults.setYoutubeScheduleLockEnabled(true);

    var list = BlockScheduleStore.loadAll();
    final idx = list.indexWhere((s) => s.id == timelockScheduleId);
    final schedule = BlockSchedule(
      id: timelockScheduleId,
      name: timelockScheduleName,
      enabled: true,
      locked: true,
      lockCooldownMinutes: 60,
      slots: allDaySlots,
      domains: BlockSchedule.defaultYoutubeDomains,
      blockIsleInApp: true,
    );
    if (idx >= 0) {
      list[idx] = schedule;
    } else {
      list = [...list, schedule];
    }
    await BlockScheduleStore.saveAll(list);
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    if (await IosScreenTimeService.isAvailable() && !await IosScreenTimeService.isAuthorized()) {
      await IosScreenTimeService.requestAuthorization();
    }
    return true;
  }

  static Future<void> disable() async {
    IsleUserDefaults.setYoutubeTimelockEnabled(false);
    final list = BlockScheduleStore.loadAll();
    final idx = list.indexWhere((s) => s.id == timelockScheduleId);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(enabled: false);
      await BlockScheduleStore.saveAll(list);
    }
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
  }
}
