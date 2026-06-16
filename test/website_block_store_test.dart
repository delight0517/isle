import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/intervention/website_block_store.dart';

void main() {
  group('WebsiteBlockStore.normalizeDomain', () {
    test('strips scheme and www', () {
      expect(
        WebsiteBlockStore.normalizeDomain('https://www.youtube.com/watch?v=1'),
        'youtube.com',
      );
    });

    test('rejects invalid', () {
      expect(WebsiteBlockStore.normalizeDomain('not a domain'), isNull);
      expect(WebsiteBlockStore.normalizeDomain(''), isNull);
    });
  });
}
