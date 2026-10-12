import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/block/premade_block_pack_registry.dart';
import 'package:isle/core/block/schedule_premade_block_pack_service.dart';
import 'package:isle/core/block/premade_block_pack_service.dart';
import 'package:isle/core/intervention/website_block_store.dart';
import 'package:isle/core/safety/adult_protection_service.dart';
import 'package:isle/core/services/isle_user_defaults.dart';
import 'package:isle/core/youtube/blocked_channel_store.dart';
import 'package:isle/core/youtube/blocked_url_store.dart';
import 'package:isle/core/youtube/content_filter_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_adult_protection_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await ContentFilterStore.ensureOpen();
    await BlockedChannelStore.ensureOpen();
    await BlockedUrlStore.ensureOpen();
    await WebsiteBlockStore.ensureOpen();
  });

  setUp(() {
    AdultProtectionService.resetMigrationForTest();
  });

  tearDown(() async {
    await Hive.box<String>('isle_cache').clear();
  });

  test('migrate from content safety only → basic', () async {
    await IsleUserDefaults.setContentSafetyEnabled(true);
    await AdultProtectionService.migrateIfNeeded();
    expect(AdultProtectionService.tier, AdultProtectionTier.basic);
    expect(IsleUserDefaults.adultProtectionTier, AdultProtectionTier.basic.storageKey);
  });

  test('migrate from applied combined pack → full', () async {
    await IsleUserDefaults.markPremadeBlockPackApplied(
      PremadeBlockPackService.adultCombinedPackId,
      version: '1.0.0',
    );
    await AdultProtectionService.migrateIfNeeded();
    expect(AdultProtectionService.tier, AdultProtectionTier.full);
  });

  test('setTier off disables content safety', () async {
    await IsleUserDefaults.setAdultProtectionTier(AdultProtectionTier.basic.storageKey);
    await IsleUserDefaults.setContentSafetyEnabled(true);
    await AdultProtectionService.setTier(AdultProtectionTier.off);
    expect(AdultProtectionService.tier, AdultProtectionTier.off);
    expect(IsleUserDefaults.contentSafetyEnabled, isFalse);
  });

  test('ensureFullPackApplied when tier full but pack missing', () async {
    await IsleUserDefaults.setAdultProtectionTier(AdultProtectionTier.full.storageKey);
    await IsleUserDefaults.setContentSafetyEnabled(true);
    await PremadeBlockPackRegistry.ensureLoaded();

    final result = await AdultProtectionService.ensureFullPackApplied();
    expect(result.packApplied, isTrue);
    expect(AdultProtectionService.fullPackApplied, isTrue);
    expect(result.message, isNotNull);
  });

  test('adult pack blocked from schedule link', () async {
    await PremadeBlockPackRegistry.ensureLoaded();
    await expectLater(
      SchedulePremadePackService.linkPack(
        scheduleId: 'x',
        packId: PremadeBlockPackService.adultCombinedPackId,
      ),
      throwsA(
        predicate<Object>((e) =>
            e is StateError &&
            e.message.contains('성인 보호는 보호 필터에서만')),
      ),
    );
  });
}
