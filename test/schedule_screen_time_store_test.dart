import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:isle/core/block_schedule/block_schedule_store.dart';
import 'package:isle/core/block_schedule/models/block_schedule.dart';
import 'package:isle/core/block_schedule/schedule_app_target_catalog.dart';
import 'package:isle/core/block_schedule/schedule_app_targets_service.dart';
import 'package:isle/core/intervention/schedule_screen_time_store.dart';

void main() {
  late Directory directory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory =
        Directory.systemTemp.createTempSync('moa_screen_time_store_test');
    Hive.init(directory.path);
    await ScheduleScreenTimeStore.ensureOpen();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    directory.deleteSync(recursive: true);
  });

  test('selections are isolated by schedule and iPhone app bundle', () async {
    await ScheduleScreenTimeStore.savePick(
      scheduleId: 'night',
      bundleId: 'youtube',
      encoded: 'youtube-token',
      applicationCount: 1,
      categoryCount: 0,
    );
    await ScheduleScreenTimeStore.savePick(
      scheduleId: 'night',
      bundleId: 'safari',
      encoded: 'safari-token',
      applicationCount: 1,
      categoryCount: 0,
    );

    expect(ScheduleScreenTimeStore.encodedFor('night', bundleId: 'youtube'),
        'youtube-token');
    expect(ScheduleScreenTimeStore.encodedFor('night', bundleId: 'safari'),
        'safari-token');
    expect(ScheduleScreenTimeStore.bundleIdsWithSelection('night').toSet(),
        {'youtube', 'safari'});
    expect(ScheduleScreenTimeStore.hasAnySelection('night'), isTrue);

    await ScheduleScreenTimeStore.clearBundle('night', 'youtube');
    expect(ScheduleScreenTimeStore.encodedFor('night', bundleId: 'youtube'),
        isNull);
    expect(ScheduleScreenTimeStore.encodedFor('night', bundleId: 'safari'),
        'safari-token');
  });

  test('legacy whole-schedule selection remains available as a fallback',
      () async {
    await ScheduleScreenTimeStore.savePick(
      scheduleId: 'legacy',
      encoded: 'legacy-token',
      applicationCount: 2,
      categoryCount: 1,
    );
    expect(ScheduleScreenTimeStore.encodedFor('legacy'), 'legacy-token');
    expect(ScheduleScreenTimeStore.appCountFor('legacy'), 2);
  });

  test('legacy selections migrate once without overwriting narrowed app picks',
      () async {
    const scheduleId = 'migration';
    await BlockScheduleStore.ensureOpen();
    await BlockScheduleStore.saveAll([
      const BlockSchedule(id: scheduleId, name: 'migration test'),
    ]);
    await ScheduleScreenTimeStore.box.delete('__migrated_per_bundle_v1');
    await ScheduleScreenTimeStore.savePick(
      scheduleId: scheduleId,
      encoded: 'legacy-union',
      applicationCount: 3,
      categoryCount: 0,
    );
    await ScheduleScreenTimeStore.savePick(
      scheduleId: scheduleId,
      bundleId: 'kakao_talk',
      encoded: 'kakao-narrowed',
      applicationCount: 1,
      categoryCount: 0,
    );

    await ScheduleAppTargetsService.migrateLegacyScreenTimeSelectionsIfNeeded();

    expect(
      ScheduleScreenTimeStore.encodedFor(scheduleId, bundleId: 'kakao_talk'),
      'kakao-narrowed',
    );
    for (final target in ScheduleAppTargetCatalog.iosTargets()) {
      if (target.bundleId == 'kakao_talk') continue;
      expect(
        ScheduleScreenTimeStore.encodedFor(scheduleId,
            bundleId: target.bundleId),
        'legacy-union',
      );
    }
    expect(ScheduleScreenTimeStore.migratedToPerBundle, isTrue);
    await ScheduleAppTargetsService.migrateLegacyScreenTimeSelectionsIfNeeded();
    expect(
      ScheduleScreenTimeStore.encodedFor(scheduleId, bundleId: 'kakao_talk'),
      'kakao-narrowed',
    );
  });
}
