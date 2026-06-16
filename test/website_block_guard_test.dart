import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/intervention/website_block_guard.dart';
import 'package:isle/core/intervention/website_block_store.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_web_block_test');
    Hive.init(dir.path);
    await WebsiteBlockStore.ensureOpen();
    await WebsiteBlockStore.saveDomains(['instagram.com', 'tiktok.com']);
  });

  test('m.youtube.com matches youtube.com block via suffix', () async {
    await WebsiteBlockStore.saveDomains(['youtube.com', 'instagram.com']);
    expect(
      WebsiteBlockGuard.matchUrl('https://m.youtube.com/watch?v=abc'),
      isNotNull,
    );
  });

  test('www.instagram.com matches instagram.com', () {
    expect(
      WebsiteBlockGuard.matchUrl('https://www.instagram.com/reels/'),
      isNotNull,
    );
  });

  test('unblocked site returns null', () {
    expect(WebsiteBlockGuard.matchUrl('https://brunch.co.kr'), isNull);
  });
}
