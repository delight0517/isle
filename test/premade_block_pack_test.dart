import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/block/premade_block_pack_service.dart';
import 'package:isle/core/intervention/website_block_store.dart';
import 'package:isle/core/youtube/blocked_channel_store.dart';
import 'package:isle/core/youtube/blocked_url_store.dart';
import 'package:isle/core/youtube/content_filter_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_premade_pack_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await ContentFilterStore.ensureOpen();
    await BlockedChannelStore.ensureOpen();
    await BlockedUrlStore.ensureOpen();
    await WebsiteBlockStore.ensureOpen();
  });

  test('catalog loads three premade packs from assets', () async {
    final packs = await PremadeBlockPackService.loadCatalog();
    expect(packs.length, 3);
    expect(packs.any((p) => p.packId == 'premade_adult_youtube_200'), isTrue);
    expect(packs.any((p) => p.packId == 'premade_gaming_400'), isTrue);
    final adultYt = packs.firstWhere((p) => p.packId == 'premade_adult_youtube_200');
    expect(adultYt.entryCount, 200);
    expect(adultYt.entries.first.kind, 'channelURL');
  });

  test('apply adult youtube pack adds channel keyword and url', () async {
    await ContentFilterStore.saveKeywords([]);
    await BlockedChannelStore.saveAll([]);
    await BlockedUrlStore.saveAll([]);
    final result = await PremadeBlockPackService.applyPack('premade_adult_youtube_200');
    expect(result.channelsAdded, greaterThan(0));
    expect(result.keywordsAdded, greaterThan(0));
    expect(result.urlsAdded, greaterThan(0));
    expect(BlockedChannelStore.loadAll().any((c) => c.channelId == '@pornhub'), isTrue);
    expect(ContentFilterStore.loadKeywords(), contains('pornhub'));
  });
}
