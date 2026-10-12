import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/block_schedule.dart';
import 'package:isle/core/block_schedule/models/pending_schedule_target_edit.dart';
import 'package:isle/core/block_schedule/models/schedule_app_target_entry.dart';
import 'package:isle/core/block_schedule/quick_block_service.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/block_schedule/schedule_pending_target_service.dart';
import 'package:isle/core/block_schedule/schedule_pending_target_store.dart';
import 'package:isle/core/intervention/app_usage_limit_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/intervention/schedule_screen_time_store.dart';
import 'package:isle/core/intervention/website_block_store.dart';
import 'package:isle/core/services/isle_user_defaults.dart';

void main() {
  const scheduleId = 'timer_locked_schedule';
  const targetId = 'isle_youtube';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('isle_schedule_pending_target_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await SchedulePendingTargetStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await WebsiteBlockStore.ensureOpen();
    await QuickBlockService.ensureOpen();
  });

  setUp(() async {
    await IsleUserDefaults.setYoutubeScheduleLockEnabled(false);
    await ExternalAppShieldStore.setSyncWithBlockSchedule(true);
    await BlockScheduleStore.saveAll([
      const BlockSchedule(
        id: scheduleId,
        name: '타이머락 스케줄',
        locked: true,
        lockCooldownMinutes: 1,
      ),
    ]);
    await SchedulePendingTargetStore.saveAll([]);
    await ScheduleAppTargetsStore.saveForSchedule(scheduleId, [
      const ScheduleAppTargetEntry(targetId: targetId),
    ]);
  });

  test('locked schedule queues target edit and can cancel it', () async {
    final schedule = BlockScheduleStore.loadAll().single;
    const current = ScheduleAppTargetEntry(targetId: targetId);
    final desired = current.copyWith(blockInSlot: true);

    final outcome = await SchedulePendingTargetService.requestEntryChange(
      schedule: schedule,
      desired: desired,
      currentPersisted: current,
    );

    expect(outcome.kind, ScheduleTargetChangeOutcomeKind.scheduled);
    expect(outcome.startedCountdown, isTrue);
    expect(SchedulePendingTargetService.pendingEntry(scheduleId, targetId), isNotNull);
    expect(
      ScheduleAppTargetsStore.entryFor(scheduleId, targetId)?.blockInSlot,
      isFalse,
    );

    await SchedulePendingTargetService.cancelEntry(scheduleId, targetId);
    expect(SchedulePendingTargetService.pendingEntry(scheduleId, targetId), isNull);
  });

  test('queued target edit applies after timer wait', () async {
    final schedule = BlockScheduleStore.loadAll().single;
    const current = ScheduleAppTargetEntry(targetId: targetId);
    final desired = current.copyWith(blockInSlot: true);

    await SchedulePendingTargetService.requestEntryChange(
      schedule: schedule,
      desired: desired,
      currentPersisted: current,
    );

    final past = DateTime.now().subtract(const Duration(minutes: 2));
    final unlockedSchedule = BlockScheduleStore.loadAll().single.copyWith(
          unlockStartedAtMs: past.millisecondsSinceEpoch,
        );
    await BlockScheduleStore.saveAll([unlockedSchedule]);

    final pending = SchedulePendingTargetStore.loadAll().single;
    await SchedulePendingTargetStore.saveAll([
      PendingScheduleTargetEdit(
        scheduleId: pending.scheduleId,
        kind: pending.kind,
        targetId: pending.targetId,
        entry: pending.entry,
        applyAtMs: past.millisecondsSinceEpoch,
        scheduledAtMs: pending.scheduledAtMs,
      ),
    ]);

    final applied = await SchedulePendingTargetService.processDue();

    expect(applied, 1);
    expect(SchedulePendingTargetStore.loadAll(), isEmpty);
    expect(
      ScheduleAppTargetsStore.entryFor(scheduleId, targetId)?.blockInSlot,
      isTrue,
    );
  });
}
