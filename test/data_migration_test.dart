import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/intervention/website_block_store.dart';
import 'package:isle/core/services/isle_data_migration_service.dart';
import 'package:isle/core/youtube/content_filter_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_migration_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await ContentFilterStore.ensureOpen();
    await WebsiteBlockStore.ensureOpen();
  });

  setUp(() async {
    await Hive.box<String>('isle_cache').clear();
    await ContentFilterStore.saveKeywords(['starcraft', 'shorts', 'asmr', 'pornhub']);
  });

  test('migration strips broad youtube keywords without wiping good ones', () async {
    await IsleDataMigrationService.runAfterStoresOpen();
    expect(ContentFilterStore.loadKeywords(), ['pornhub', 'starcraft']);
    expect(
      Hive.box<String>('isle_cache').get('isle_data_schema_v'),
      '${IsleDataMigrationService.dataSchemaVersion}',
    );
  });
}
