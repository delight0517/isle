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

  group('builtInAdultSearchKeywords — link aggregator entry path', () {
    // "주소모아" 검색 → Google SERP 카드에 성인·도박 링크 허브가 그대로
    // 노출되던 문제(2026-07-13, 사용자 제보 — "주소모아 검색해서 들어가는
    // 것도 막아달라"). 사이트 자체는 도메인이 계속 바뀌어 호스트 차단만으론
    // 못 따라잡지만, 검색 진입 경로는 검색어 자체로 카드 단위 필터링이
    // 가능하다.
    test('includes the reported Korean link-aggregator search terms', () {
      for (final kw in ['주소모아', '주소모음', '링크모음', '최신주소', '주소가이드']) {
        expect(
          ContentSafetyGuard.builtInAdultSearchKeywords,
          contains(kw),
          reason: '"$kw" 검색 카드가 필터링돼야 함',
        );
      }
    });
  });
}
