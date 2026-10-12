import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/block_schedule.dart';
import 'package:isle/core/block_schedule/schedule_edit_guard.dart';
import 'package:isle/core/block_schedule/schedule_reservation_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir =
        Directory.systemTemp.createTempSync('isle_schedule_reservation_test');
    Hive.init(dir.path);
    await BlockScheduleStore.ensureOpen();
  });

  setUp(() async {
    await BlockScheduleStore.saveAll([]);
  });

  test('processDue activates a reservation whose activation time has passed',
      () async {
    final past = DateTime.now().subtract(const Duration(minutes: 1));
    await BlockScheduleStore.saveAll([
      BlockSchedule(
        id: 'r1',
        name: '예약 차단',
        enabled: false,
        reservationLocked: true,
        scheduledActivationAtMs: past.millisecondsSinceEpoch,
        scheduledDeactivationAtMs:
            past.add(const Duration(days: 3)).millisecondsSinceEpoch,
      ),
    ]);

    final processed = await ScheduleReservationService.processDue();
    expect(processed, 1);

    final updated = BlockScheduleStore.loadAll().single;
    expect(updated.enabled, true);
    expect(updated.scheduledActivationAtMs, isNull);
    // 활성화됐지만 아직 종료 시각 전이니 예약 잠금은 그대로 유지.
    expect(updated.reservationLocked, true);
  });

  test('processDue does not touch a reservation whose activation is future',
      () async {
    final future = DateTime.now().add(const Duration(days: 1));
    await BlockScheduleStore.saveAll([
      BlockSchedule(
        id: 'r2',
        name: '예약 차단',
        enabled: false,
        reservationLocked: true,
        scheduledActivationAtMs: future.millisecondsSinceEpoch,
        scheduledDeactivationAtMs:
            future.add(const Duration(days: 3)).millisecondsSinceEpoch,
      ),
    ]);

    final processed = await ScheduleReservationService.processDue();
    expect(processed, 0);

    final unchanged = BlockScheduleStore.loadAll().single;
    expect(unchanged.enabled, false);
    expect(unchanged.scheduledActivationAtMs, isNotNull);
  });

  test('processDue deactivates and unlocks once deactivation time has passed',
      () async {
    final past = DateTime.now().subtract(const Duration(minutes: 1));
    await BlockScheduleStore.saveAll([
      BlockSchedule(
        id: 'r3',
        name: '예약 차단',
        enabled: true,
        reservationLocked: true,
        scheduledDeactivationAtMs: past.millisecondsSinceEpoch,
      ),
    ]);

    final processed = await ScheduleReservationService.processDue();
    expect(processed, 1);

    final updated = BlockScheduleStore.loadAll().single;
    expect(updated.enabled, false);
    expect(updated.scheduledDeactivationAtMs, isNull);
    expect(updated.reservationLocked, false);
  });

  test(
      'ScheduleEditGuard.isCommitmentLocked stays true through the whole '
      'reservation window regardless of the normal locked/lockPhase state',
      () {
    final now = DateTime.now();
    final reserved = BlockSchedule(
      id: 'r4',
      name: '예약 차단',
      enabled: true,
      locked: false, // 일반 커밋먼트 락은 꺼져 있어도 예약 잠금은 별개로 막아야 한다.
      reservationLocked: true,
      scheduledDeactivationAtMs:
          now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
    );
    expect(ScheduleEditGuard.isCommitmentLocked(reserved, now), true);

    final afterEnd = BlockSchedule(
      id: 'r5',
      name: '예약 차단',
      enabled: true,
      locked: false,
      reservationLocked: true,
      scheduledDeactivationAtMs:
          now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
    );
    expect(ScheduleEditGuard.isCommitmentLocked(afterEnd, now), false);
  });
}
