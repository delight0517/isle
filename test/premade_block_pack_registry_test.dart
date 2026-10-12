import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/block/premade_block_pack_registry.dart';
import 'package:isle/core/block/premade_block_pack_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_registry_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await PremadeBlockPackRegistry.ensureLoaded();
  });

  test('manifest registers all 4VPN packs', () {
    expect(PremadeBlockPackRegistry.definitions.length, 4);
    expect(PremadeBlockPackRegistry.toggleDefinitions().length, 3);
    expect(PremadeBlockPackRegistry.scheduleEligibleDefinitions().length, 2);
    expect(
        PremadeBlockPackRegistry.adultCombinedPackId, 'premade_adult_combined');
  });

  test('loadCatalog includes adult combined pack', () async {
    PremadeBlockPackService.invalidateCatalogCache();
    final packs = await PremadeBlockPackService.loadCatalog();
    expect(packs.length, 4);
    expect(packs.first.packId, 'premade_adult_combined');
    expect(packs.any((p) => p.packId == 'premade_gaming_400'), isTrue);
    expect(packs.any((p) => p.packId == 'premade_gambling_200'), isTrue);
    expect(
        packs.any((p) => p.packId == 'premade_jusoland_illegal_sites'), isTrue);

    final toggle = await PremadeBlockPackService.loadToggleCatalog();
    expect(toggle.length, 3);
    expect(toggle.any((p) => p.packId == 'premade_adult_combined'), isFalse);
  });

  test('merged adult includes all manifest merge sources', () async {
    final adult = await PremadeBlockPackService.loadMergedAdultPack();
    expect(adult, isNotNull);
    expect(adult!.entryCount, greaterThan(500));
    expect(adult.entries.any((e) => e.pattern == '@pornhub'), isTrue);
  });

  test('legacy pack id resolves to adult combined', () {
    expect(
      PremadeBlockPackRegistry.resolvePackId('premade_adult_sites_200'),
      'premade_adult_combined',
    );
    expect(
      PremadeBlockPackRegistry.resolvePackId('premade_link_aggregator_seo'),
      'premade_adult_combined',
    );
  });
}
