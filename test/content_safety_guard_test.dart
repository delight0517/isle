import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/safety/adult_domain_catalog.dart';
import 'package:isle/core/safety/content_safety_guard.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_safety_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
  });

  group('AdultDomainCatalog', () {
    test('blocks major adult suffixes', () {
      expect(AdultDomainCatalog.hostMatches('www.pornhub.com'), isTrue);
      expect(AdultDomainCatalog.hostMatches('m.xvideos.com'), isTrue);
      expect(AdultDomainCatalog.hostMatches('onlyfans.com'), isTrue);
    });

    test('allows normal sites', () {
      expect(AdultDomainCatalog.hostMatches('youtube.com'), isFalse);
      expect(AdultDomainCatalog.hostMatches('google.com'), isFalse);
      expect(AdultDomainCatalog.hostMatches('brunch.co.kr'), isFalse);
    });
  });

  group('ContentSafetyGuard.sanitizeUrl', () {
    test('adds bing strict when enabled', () {
      final out = ContentSafetyGuard.sanitizeUrl(
        'https://www.bing.com/search?q=test',
      );
      expect(out, contains('adlt=strict'));
    });

    test('adds duckduckgo kp when enabled', () {
      final out = ContentSafetyGuard.sanitizeUrl(
        'https://duckduckgo.com/?q=test',
      );
      expect(out, contains('kp=1'));
    });
  });
}
