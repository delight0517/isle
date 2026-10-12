import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/pomodoro_wake_lock_sync.dart';
import 'package:isle/core/block_schedule/schedule_active_service.dart';
import 'package:isle/core/block_schedule/schedule_target_access_guard.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/intervention/app_usage_limit_store.dart';
import 'package:isle/core/intervention/website_block_store.dart';
import 'package:isle/core/services/isle_user_defaults.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('isle_wake_lock_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await WebsiteBlockStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
  });

  setUp(() async {
    await BlockScheduleStore.saveAll([]);
    await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);
    await IsleUserDefaults.setPomodoroWakeLastEventAtMs(0);
    await IsleUserDefaults.setPomodoroWakeLockTargetIds(
      IsleUserDefaults.pomodoroWakeDefaultTargetIds,
    );
  });

  final wakeAt = DateTime(2026, 10, 11, 7).millisecondsSinceEpoch;
  final now = DateTime(2026, 10, 11, 7, 12);
  final snapshot = {
    'settings': {'wakeLockEnabled': true},
  };
  Map<String, dynamic> wakeState({
    int? at,
    String source = 'user-confirmed',
    Object? durationSeconds,
    Object? samples,
    String id = 'wake-1',
  }) {
    final event = <String, dynamic>{
      'id': id,
      'source': source,
      if (source == 'risesync-sleep-confirmed') 'sleepAt': at ?? wakeAt,
      if (source != 'risesync-sleep-confirmed') 'wakeAt': at ?? wakeAt,
    };
    if (durationSeconds != null) {
      event['evidenceDurationSeconds'] = durationSeconds;
    }
    if (samples != null) {
      event['evidenceSampleCount'] = samples;
    }
    return {'wakeEvent': event};
  }

  test('applies an exact two-hour lock to MOA Instagram, DMs, and YouTube',
      () async {
    final result = await PomodoroWakeLockSync.applyRemoteState(
      snapshot: snapshot,
      wakeState: wakeState(),
      now: now,
    );

    expect(result, PomodoroWakeLockSyncResult.applied);
    final schedule = BlockScheduleStore.loadAll().single;
    expect(schedule.id, PomodoroWakeLockSync.scheduleId);
    expect(schedule.enabled, isTrue);
    expect(schedule.reservationLocked, isTrue);
    expect(schedule.scheduledDeactivationAtMs,
        wakeAt + const Duration(hours: 2).inMilliseconds);
    expect(ScheduleTargetAccessGuard.isTargetBlocked('isle_instagram', now),
        isTrue);
    expect(ScheduleTargetAccessGuard.isTargetBlocked('isle_instagram_dm', now),
        isTrue);
    expect(
        ScheduleTargetAccessGuard.isTargetBlocked('isle_youtube', now), isTrue);
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      wakeAt + const Duration(hours: 2).inMilliseconds,
    );
    expect(ScheduleActiveService.isScheduleActiveNow(schedule, expiresAt),
        isFalse);
    expect(
        ScheduleTargetAccessGuard.isTargetBlocked('isle_instagram', expiresAt),
        isFalse);
    final entries = ScheduleAppTargetsStore.loadForSchedule(schedule.id);
    for (final id in PomodoroWakeLockSync.targetIds) {
      expect(entries.singleWhere((e) => e.targetId == id).blockInSlot, isTrue);
    }
    expect(entries.singleWhere((e) => e.targetId == 'isle_brunch').blockInSlot,
        isFalse);
  });

  test('duplicate foreground sync never extends the original expiry', () async {
    await PomodoroWakeLockSync.applyRemoteState(
      snapshot: snapshot,
      wakeState: wakeState(),
      now: now,
    );

    final result = await PomodoroWakeLockSync.applyRemoteState(
      snapshot: snapshot,
      wakeState: wakeState(),
      now: now.add(const Duration(minutes: 50)),
    );

    expect(result, PomodoroWakeLockSyncResult.applied);
    expect(BlockScheduleStore.loadAll().single.scheduledDeactivationAtMs,
        wakeAt + const Duration(hours: 2).inMilliseconds);
  });

  test('wake lock applies only the locally selected MOA targets', () async {
    await IsleUserDefaults.setPomodoroWakeLockTargetIds(
      {'isle_youtube', 'isle_customweb'},
    );

    final result = await PomodoroWakeLockSync.applyRemoteState(
      snapshot: snapshot,
      wakeState: wakeState(),
      now: now,
    );

    expect(result, PomodoroWakeLockSyncResult.applied);
    expect(ScheduleTargetAccessGuard.isTargetBlocked('isle_instagram', now),
        isFalse);
    expect(ScheduleTargetAccessGuard.isTargetBlocked('isle_instagram_dm', now),
        isFalse);
    expect(
        ScheduleTargetAccessGuard.isTargetBlocked('isle_youtube', now), isTrue);
    expect(ScheduleTargetAccessGuard.isTargetBlocked('isle_customweb', now),
        isTrue);
    expect(
        ScheduleTargetAccessGuard.isTargetBlocked('isle_brunch', now), isFalse);
  });

  test('changing targets while awake updates the current wake lock', () async {
    await PomodoroWakeLockSync.applyRemoteState(
      snapshot: snapshot,
      wakeState: wakeState(),
      now: now,
    );

    await PomodoroWakeLockSync.setBlockedTargets({'isle_customweb'});

    expect(ScheduleTargetAccessGuard.isTargetBlocked('isle_instagram', now),
        isFalse);
    expect(ScheduleTargetAccessGuard.isTargetBlocked('isle_customweb', now),
        isTrue);
  });

  test('ignores weak computer activity evidence', () async {
    final result = await PomodoroWakeLockSync.applyRemoteState(
      snapshot: snapshot,
      wakeState: wakeState(
        source: 'pomodoro-activity',
        durationSeconds: 40,
        samples: 1,
      ),
      now: now,
    );

    expect(result, PomodoroWakeLockSyncResult.ignored);
    expect(BlockScheduleStore.loadAll(), isEmpty);
  });

  test('does not apply a wake window that has already elapsed', () async {
    final result = await PomodoroWakeLockSync.applyRemoteState(
      snapshot: snapshot,
      wakeState: wakeState(),
      now: DateTime(2026, 10, 11, 9),
    );

    expect(result, PomodoroWakeLockSyncResult.expired);
    expect(BlockScheduleStore.loadAll(), isEmpty);
  });

  test('confirmed sleep ends only a newer active wake lock', () async {
    await PomodoroWakeLockSync.applyRemoteState(
      snapshot: snapshot,
      wakeState: wakeState(),
      now: now,
    );

    final result = await PomodoroWakeLockSync.applyRemoteState(
      snapshot: snapshot,
      wakeState: wakeState(
        at: wakeAt + const Duration(minutes: 20).inMilliseconds,
        source: 'risesync-sleep-confirmed',
        id: 'sleep-1',
      ),
      now: now.add(const Duration(minutes: 21)),
    );

    expect(result, PomodoroWakeLockSyncResult.endedBySleep);
    expect(BlockScheduleStore.loadAll().single.enabled, isFalse);
    expect(BlockScheduleStore.loadAll().single.reservationLocked, isFalse);
  });

  test('Auto Pomodoro disabling wake lock removes MOA temporary lock',
      () async {
    await PomodoroWakeLockSync.applyRemoteState(
      snapshot: snapshot,
      wakeState: wakeState(),
      now: now,
    );

    final result = await PomodoroWakeLockSync.applyRemoteState(
      snapshot: {
        'settings': {'wakeLockEnabled': false},
      },
      wakeState: wakeState(),
      now: now.add(const Duration(minutes: 10)),
    );

    expect(result, PomodoroWakeLockSyncResult.disabled);
    expect(BlockScheduleStore.loadAll().single.enabled, isFalse);
  });
}
