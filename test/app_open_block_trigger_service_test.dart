import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/block_schedule/app_open_block_trigger_service.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/quick_block_service.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_store.dart';
import 'package:isle/core/intervention/app_usage_limit_store.dart';
import 'package:isle/core/intervention/external_app_shield_store.dart';
import 'package:isle/core/intervention/schedule_screen_time_store.dart';
import 'package:isle/core/intervention/website_block_store.dart';
import 'package:isle/core/services/isle_user_defaults.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir =
        Directory.systemTemp.createTempSync('isle_app_open_trigger_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await ScheduleScreenTimeStore.ensureOpen();
    await ExternalAppShieldStore.ensureOpen();
    await AppUsageLimitStore.ensureOpen();
    await WebsiteBlockStore.ensureOpen();
    await QuickBlockService.ensureOpen();
  });

  setUp(() async {
    await ExternalAppShieldStore.setSyncWithBlockSchedule(true);
    await BlockScheduleStore.saveAll([]);
    await IsleUserDefaults.setAppOpenTriggerEnabled(false);
    await IsleUserDefaults.setAppOpenTriggerDurationMinutes(30);
    await IsleUserDefaults.setAppOpenTriggerTargetIds([]);
    await IsleUserDefaults.setAppOpenTriggerMorningOnly(false);
    await IsleUserDefaults.setAppOpenTriggerCutoffHour(11);
    await IsleUserDefaults.setAppOpenTriggerBlockSafari(false);
    // "오늘 이미 발동했음" 상태가 이전 테스트에서 넘어오지 않게 리셋 —
    // 확실히 과거인 날짜로 되돌려 "아직 발동 전"과 동일하게 만든다.
    await IsleUserDefaults.setAppOpenTriggerLastDateKey('2000-01-01');
  });

  test('disabled by default — does not create a schedule', () async {
    final triggered = await AppOpenBlockTriggerService.maybeTriggerOnAppOpen();
    expect(triggered, false);
    expect(BlockScheduleStore.loadAll(), isEmpty);
  });

  test('enabled + target set → activates on first call today', () async {
    await IsleUserDefaults.setAppOpenTriggerEnabled(true);
    await IsleUserDefaults.setAppOpenTriggerTargetIds(['isle_youtube']);
    await IsleUserDefaults.setAppOpenTriggerDurationMinutes(30);

    final triggered = await AppOpenBlockTriggerService.maybeTriggerOnAppOpen();
    expect(triggered, true);

    final schedule = BlockScheduleStore.loadAll()
        .where((s) => s.id == AppOpenBlockTriggerService.scheduleId)
        .single;
    expect(schedule.enabled, true);
    expect(schedule.reservationLocked, true);
    expect(schedule.locked, false); // 자기잠금 방지 — 문서화된 설계결정
    expect(schedule.scheduledDeactivationAtMs, isNotNull);
    final remaining = DateTime.fromMillisecondsSinceEpoch(
      schedule.scheduledDeactivationAtMs!,
    ).difference(DateTime.now());
    expect(remaining.inMinutes, inInclusiveRange(28, 30));
  });

  test('same-day second call does not re-trigger', () async {
    await IsleUserDefaults.setAppOpenTriggerEnabled(true);
    await IsleUserDefaults.setAppOpenTriggerTargetIds(['isle_youtube']);

    final first = await AppOpenBlockTriggerService.maybeTriggerOnAppOpen();
    expect(first, true);
    final second = await AppOpenBlockTriggerService.maybeTriggerOnAppOpen();
    expect(second, false);
  });

  test('morningOnly + already past cutoff hour → skips today, keeps trying tomorrow',
      () async {
    await IsleUserDefaults.setAppOpenTriggerEnabled(true);
    await IsleUserDefaults.setAppOpenTriggerTargetIds(['isle_youtube']);
    await IsleUserDefaults.setAppOpenTriggerMorningOnly(true);
    // 컷오프를 지금보다 확실히 이른 시각으로 둬서 "이미 지남" 상태를 만든다.
    final pastHour = (DateTime.now().hour - 1).clamp(0, 23);
    await IsleUserDefaults.setAppOpenTriggerCutoffHour(pastHour);

    final triggered = await AppOpenBlockTriggerService.maybeTriggerOnAppOpen();
    if (DateTime.now().hour > pastHour) {
      expect(triggered, false);
      expect(BlockScheduleStore.loadAll(), isEmpty);
      // 오늘치를 스킵했어도 lastDateKey는 그대로 안 남아 내일 재시도 가능해야 함.
      expect(
        IsleUserDefaults.appOpenTriggerLastDateKey,
        isNot(AppOpenBlockTriggerService.dateKey(DateTime.now())),
      );
    }
  });

  test('reactivating on a later day reuses the same schedule id (no duplicates)',
      () async {
    await IsleUserDefaults.setAppOpenTriggerEnabled(true);
    await IsleUserDefaults.setAppOpenTriggerTargetIds(['isle_youtube']);
    await AppOpenBlockTriggerService.maybeTriggerOnAppOpen();

    // 어제 이미 끝난 것처럼 시뮬레이션: 스케줄을 비활성화하고, lastDateKey를
    // 어제 날짜로 되돌려 "새로운 하루"처럼 만든다.
    final list = BlockScheduleStore.loadAll();
    final idx = list.indexWhere((s) => s.id == AppOpenBlockTriggerService.scheduleId);
    list[idx] = list[idx].copyWith(
      enabled: false,
      reservationLocked: false,
      clearScheduledDeactivation: true,
    );
    await BlockScheduleStore.saveAll(list);
    await IsleUserDefaults.setAppOpenTriggerLastDateKey(
      AppOpenBlockTriggerService.dateKey(
        DateTime.now().subtract(const Duration(days: 1)),
      ),
    );

    final triggered = await AppOpenBlockTriggerService.maybeTriggerOnAppOpen();
    expect(triggered, true);
    final schedules = BlockScheduleStore.loadAll()
        .where((s) => s.id == AppOpenBlockTriggerService.scheduleId)
        .toList();
    expect(schedules.length, 1); // 재사용 — 중복 생성 안 됨
    expect(schedules.single.enabled, true);
  });
}
