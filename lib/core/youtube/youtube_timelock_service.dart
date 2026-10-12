import '../block_schedule/models/schedule_app_target_entry.dart';
import '../block_schedule/schedule_app_targets_service.dart';
import '../block_schedule/schedule_app_targets_store.dart';
import '../block_schedule/block_schedule_enforcement_service.dart';
import '../block_schedule/block_schedule_store.dart';
import '../block_schedule/models/block_schedule.dart';
import '../block_schedule/models/schedule_slot.dart';
import '../block_schedule/schedule_lock_phase.dart';
import '../block_schedule/schedule_lock_service.dart';
import '../platform/ios_screen_time_service.dart';
import '../services/isle_user_defaults.dart';

/// 타임락 방식 — Isle WebView + 스케줄(24h) + iOS Screen Time 동기화
class YoutubeTimelockService {
  YoutubeTimelockService._();

  static const timelockScheduleId = 'isle_youtube_timelock';
  static const timelockScheduleName = 'YouTube 전체 차단 (타임락)';
  static const defaultCooldownMinutes = 15;
  static const cooldownChoices = [15, 30, 60, 120];

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

  static BlockSchedule? get schedule {
    final list = BlockScheduleStore.loadAll();
    return list.cast<BlockSchedule?>().firstWhere(
          (s) => s?.id == timelockScheduleId,
          orElse: () => null,
        );
  }

  static bool get disablePending => IsleUserDefaults.youtubeTimelockDisablePending;

  static Duration? get disableRemaining {
    final s = schedule;
    if (s == null || !disablePending) return null;
    return ScheduleLockService.countdownRemaining(s);
  }

  static Future<bool> enable() async {
    await BlockScheduleStore.ensureOpen();
    await IsleUserDefaults.setYoutubeTimelockEnabled(true);
    await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);

    var list = BlockScheduleStore.loadAll();
    final idx = list.indexWhere((s) => s.id == timelockScheduleId);
    final schedule = BlockSchedule(
      id: timelockScheduleId,
      name: timelockScheduleName,
      enabled: true,
      locked: true,
      lockCooldownMinutes: defaultCooldownMinutes,
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
    await IsleUserDefaults.setYoutubeTimelockDisablePending(false);
    await _syncIsleYoutubeTarget(schedule);
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    if (await IosScreenTimeService.isAvailable() && !await IosScreenTimeService.isAuthorized()) {
      await IosScreenTimeService.requestAuthorization();
    }
    return true;
  }

  static Future<void> disable() async {
    await IsleUserDefaults.setYoutubeTimelockEnabled(false);
    await IsleUserDefaults.setYoutubeTimelockDisablePending(false);
    final list = BlockScheduleStore.loadAll();
    final idx = list.indexWhere((s) => s.id == timelockScheduleId);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(enabled: false);
      await BlockScheduleStore.saveAll(list);
    }
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
  }

  static Future<YoutubeTimelockDisableRequest> requestDisable() async {
    await BlockScheduleStore.ensureOpen();
    if (!isActive) {
      await IsleUserDefaults.setYoutubeTimelockDisablePending(false);
      return const YoutubeTimelockDisableRequest.alreadyOff();
    }

    final s = schedule;
    if (s == null || !s.locked) {
      await disable();
      return const YoutubeTimelockDisableRequest.disabledNow();
    }

    final phase = ScheduleLockService.phase(s);
    if (phase == ScheduleLockPhase.editWindow) {
      await disable();
      return const YoutubeTimelockDisableRequest.disabledNow();
    }

    if (phase != ScheduleLockPhase.countdown) {
      await ScheduleLockService.startUnlockCountdown(timelockScheduleId);
    }
    await IsleUserDefaults.setYoutubeTimelockDisablePending(true);
    final updated = schedule ?? s;
    return YoutubeTimelockDisableRequest.pending(
      ScheduleLockService.countdownRemaining(updated) ??
          Duration(minutes: updated.lockCooldownMinutes),
    );
  }

  static Future<void> cancelDisableRequest() async {
    await BlockScheduleStore.ensureOpen();
    await ScheduleLockService.cancelUnlock(timelockScheduleId);
    await IsleUserDefaults.setYoutubeTimelockDisablePending(false);
  }

  static Future<bool> processPendingDisable() async {
    await BlockScheduleStore.ensureOpen();
    if (!disablePending) return false;
    final s = schedule;
    if (s == null || !s.enabled) {
      await IsleUserDefaults.setYoutubeTimelockDisablePending(false);
      return false;
    }
    final phase = ScheduleLockService.phase(s);
    if (phase == ScheduleLockPhase.editWindow) {
      await disable();
      return true;
    }
    return false;
  }

  static bool canSetCooldownMinutes(int minutes) {
    final s = schedule;
    if (s == null) return true;
    if (minutes >= s.lockCooldownMinutes) return true;
    return ScheduleLockService.phase(s) == ScheduleLockPhase.editWindow;
  }

  static Future<bool> setCooldownMinutes(int minutes) async {
    await BlockScheduleStore.ensureOpen();
    final m = minutes.clamp(defaultCooldownMinutes, 24 * 60).toInt();
    final list = BlockScheduleStore.loadAll();
    final idx = list.indexWhere((s) => s.id == timelockScheduleId);
    if (idx < 0) return false;
    final s = list[idx];
    if (m < s.lockCooldownMinutes &&
        ScheduleLockService.phase(s) != ScheduleLockPhase.editWindow) {
      return false;
    }
    list[idx] = s.copyWith(lockCooldownMinutes: m);
    await BlockScheduleStore.saveAll(list);
    return true;
  }

  static Future<void> _syncIsleYoutubeTarget(BlockSchedule schedule) async {
    await ScheduleAppTargetsStore.ensureOpen();
    var entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(schedule.id),
    );
    entries = entries
        .map(
          (e) => e.targetId == 'isle_youtube' ? e.copyWith(blockInSlot: true) : e,
        )
        .toList();
    if (!entries.any((e) => e.targetId == 'isle_youtube')) {
      entries = [
        ...entries,
        const ScheduleAppTargetEntry(targetId: 'isle_youtube', blockInSlot: true),
      ];
    }
    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: schedule.id,
      entries: entries,
      schedule: schedule,
    );
  }
}

class YoutubeTimelockDisableRequest {
  const YoutubeTimelockDisableRequest._({
    required this.kind,
    this.remaining,
  });

  final YoutubeTimelockDisableRequestKind kind;
  final Duration? remaining;

  const YoutubeTimelockDisableRequest.alreadyOff()
      : this._(kind: YoutubeTimelockDisableRequestKind.alreadyOff);

  const YoutubeTimelockDisableRequest.disabledNow()
      : this._(kind: YoutubeTimelockDisableRequestKind.disabledNow);

  const YoutubeTimelockDisableRequest.pending(Duration remaining)
      : this._(
          kind: YoutubeTimelockDisableRequestKind.pending,
          remaining: remaining,
        );
}

enum YoutubeTimelockDisableRequestKind {
  alreadyOff,
  disabledNow,
  pending,
}
