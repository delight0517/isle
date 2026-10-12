import '../platform/blue_cloud_account_service.dart';
import '../services/isle_user_defaults.dart';
import '../services/trusted_time_guard.dart';
import 'block_schedule_enforcement_service.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'models/schedule_enforcement_mode.dart';
import 'models/schedule_slot.dart';
import 'schedule_app_targets_store.dart';

enum PomodoroWakeLockSyncResult {
  applied,
  endedBySleep,
  disabled,
  expired,
  ignored,
}

/// Mirrors Auto Pomodoro's authenticated wake signal into MOA's in-app
/// Instagram/YouTube gates. The two-hour window is anchored to the source
/// wakeAt, so opening MOA later never restarts or extends it.
class PomodoroWakeLockSync {
  PomodoroWakeLockSync._();

  static bool _resumeSyncInProgress = false;

  static const scheduleId = '__isle_pomodoro_wake_lock__';
  static const duration = Duration(hours: 2);
  static const targetIds = <String>[
    'isle_instagram',
    'isle_instagram_dm',
    'isle_youtube',
  ];
  static const selectableTargetIds = <String>{
    ...targetIds,
    'isle_brunch',
    'isle_customweb',
  };

  static Future<void> setBlockedTargets(Set<String> ids) async {
    final selected = ids.intersection(selectableTargetIds);
    await IsleUserDefaults.setPomodoroWakeLockTargetIds(selected);
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    final schedule = BlockScheduleStore.loadAll()
        .where((item) => item.id == scheduleId && item.enabled)
        .firstOrNull;
    if (schedule == null) return;
    final entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(scheduleId),
    ).map((entry) {
      if (!selectableTargetIds.contains(entry.targetId)) return entry;
      return entry.copyWith(
        blockInSlot: selected.contains(entry.targetId),
        limitEnabled: false,
      );
    }).toList();
    await ScheduleAppTargetsStore.saveForSchedule(scheduleId, entries);
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
  }

  /// Refreshes the lock from BlueCloud whenever MOA returns to the foreground.
  /// No login prompt is opened; signed-out or temporarily unavailable accounts
  /// simply leave the current, expiring local schedule unchanged.
  static Future<void> syncOnResume() async {
    if (_resumeSyncInProgress) return;
    _resumeSyncInProgress = true;
    final account = BlueCloudAccountService();
    try {
      if (await account.isLoggedIn) await syncFromBlueCloud(account);
    } catch (_) {
      // Network/auth failures never fabricate a wake event or extend a lock.
    } finally {
      account.close();
      _resumeSyncInProgress = false;
    }
  }

  static Future<PomodoroWakeLockSyncResult> syncFromBlueCloud(
    BlueCloudAccountService account, {
    DateTime? now,
  }) async {
    final values = await Future.wait([
      account.fetchPomodoroSnapshot(),
      account.fetchPomodoroWakeEvent(),
    ]);
    return applyRemoteState(
      snapshot: values[0],
      wakeState: values[1],
      now: now ?? TrustedTimeGuard.effectiveNow(),
    );
  }

  /// Applies only authenticated, supported signals. Exposed separately so
  /// timestamp, stale-event, and expiry behavior can be tested without network.
  static Future<PomodoroWakeLockSyncResult> applyRemoteState({
    required Map<String, dynamic> snapshot,
    required Map<String, dynamic> wakeState,
    required DateTime now,
  }) async {
    final settings = snapshot['settings'];
    if (settings is! Map || settings['wakeLockEnabled'] is! bool) {
      return PomodoroWakeLockSyncResult.ignored;
    }

    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    final existing = BlockScheduleStore.loadAll()
        .where((schedule) => schedule.id == scheduleId)
        .firstOrNull;

    if (settings['wakeLockEnabled'] != true) {
      if (existing?.enabled == true) {
        await _writeSchedule(existing!.copyWith(
          enabled: false,
          clearScheduledDeactivation: true,
          reservationLocked: false,
        ));
      }
      return PomodoroWakeLockSyncResult.disabled;
    }

    final rawEvent = wakeState['wakeEvent'];
    if (rawEvent is! Map) return PomodoroWakeLockSyncResult.ignored;
    final event = Map<String, dynamic>.from(rawEvent);
    final source = event['source'];
    final nowMs = now.millisecondsSinceEpoch;
    final atValue = source == 'risesync-sleep-confirmed'
        ? event['sleepAt']
        : event['wakeAt'];
    if (atValue is! num) return PomodoroWakeLockSyncResult.ignored;
    final eventAt = atValue.toInt();
    if (eventAt <= 0 ||
        eventAt > nowMs + const Duration(minutes: 1).inMilliseconds) {
      return PomodoroWakeLockSyncResult.ignored;
    }

    if (source == 'risesync-sleep-confirmed') {
      if (event['id'] is! String || (event['id'] as String).isEmpty) {
        return PomodoroWakeLockSyncResult.ignored;
      }
      if (eventAt <= IsleUserDefaults.pomodoroWakeLastEventAtMs) {
        return PomodoroWakeLockSyncResult.ignored;
      }
      await IsleUserDefaults.setPomodoroWakeLastEventAtMs(eventAt);
      if (existing?.enabled == true) {
        await _writeSchedule(existing!.copyWith(
          enabled: false,
          clearScheduledDeactivation: true,
          reservationLocked: false,
        ));
      }
      return PomodoroWakeLockSyncResult.endedBySleep;
    }

    if (source is! String || !_isSupportedWake(event)) {
      return PomodoroWakeLockSyncResult.ignored;
    }
    final expiresAt = eventAt + duration.inMilliseconds;
    if (nowMs >= expiresAt) {
      await IsleUserDefaults.setPomodoroWakeLastEventAtMs(eventAt);
      if (existing?.enabled == true) {
        await _writeSchedule(existing!.copyWith(
          enabled: false,
          clearScheduledDeactivation: true,
          reservationLocked: false,
        ));
      }
      return PomodoroWakeLockSyncResult.expired;
    }

    // Replaying the same cloud event is idempotent: it retains the original
    // expiry instead of granting a fresh two hours from this sync time.
    if (eventAt <= IsleUserDefaults.pomodoroWakeLastEventAtMs) {
      if (existing?.scheduledDeactivationAtMs == expiresAt &&
          existing!.enabled) {
        return PomodoroWakeLockSyncResult.applied;
      }
      if (existing?.enabled == true) return PomodoroWakeLockSyncResult.ignored;
    }

    final schedule = BlockSchedule(
      id: scheduleId,
      name: 'Auto Pomodoro — 기상 후 2시간',
      enabled: true,
      locked: false,
      slots: [
        for (var day = 0; day < 7; day++)
          ScheduleSlot(day: day, startMinute: 0, endMinute: 1440),
      ],
      enforcementMode: ScheduleEnforcementMode.fullBlock,
      blockIsleInApp: true,
      scheduledDeactivationAtMs: expiresAt,
      reservationLocked: true,
    );
    final schedules = BlockScheduleStore.loadAll();
    final index = schedules.indexWhere((item) => item.id == scheduleId);
    if (index < 0) {
      schedules.add(schedule);
    } else {
      schedules[index] = schedule;
    }
    await BlockScheduleStore.saveAll(schedules);

    final selectedTargets = IsleUserDefaults.pomodoroWakeLockTargetIds;
    final entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(scheduleId),
    )
        .map((entry) => selectableTargetIds.contains(entry.targetId)
            ? entry.copyWith(
                blockInSlot: selectedTargets.contains(entry.targetId),
                limitEnabled: false,
              )
            : entry)
        .toList();
    await ScheduleAppTargetsStore.saveForSchedule(scheduleId, entries);
    await IsleUserDefaults.setPomodoroWakeLastEventAtMs(eventAt);
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    return PomodoroWakeLockSyncResult.applied;
  }

  static bool _isSupportedWake(Map<String, dynamic> event) {
    final source = event['source'];
    if (event['id'] is! String || (event['id'] as String).isEmpty) return false;
    if (source == 'user-confirmed') return true;
    if (source == 'risesync-nap-awake' &&
        !event.containsKey('evidenceDurationSeconds') &&
        !event.containsKey('evidenceSampleCount')) {
      return true; // Legacy authenticated RiseSync confirmation.
    }
    if (source != 'risesync-nap-awake' && source != 'pomodoro-activity') {
      return false;
    }
    final duration = event['evidenceDurationSeconds'];
    final samples = event['evidenceSampleCount'];
    return duration is num && duration >= 300 && samples is num && samples >= 2;
  }

  static Future<void> _writeSchedule(BlockSchedule schedule) async {
    final schedules = BlockScheduleStore.loadAll();
    final index = schedules.indexWhere((item) => item.id == scheduleId);
    if (index < 0) return;
    schedules[index] = schedule;
    // This service owns a single generated schedule. saveAll avoids treating
    // its temporary reservation lock as a user-editable schedule mutation.
    await BlockScheduleStore.saveAll(schedules);
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
  }
}
