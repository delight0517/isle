import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/explorer/google_search_keyword_block_script.dart';
import 'package:isle/core/explorer/safari_web_config.dart';

void main() {
  test('keyword block script targets google SERP cards', () {
    final js = GoogleSearchKeywordBlockScript.build(['스타크래프트', '쇼츠']);
    expect(js, contains('isGoogleSearch'));
    expect(js, contains('스타크래프트'));
    expect(js, contains('MjjYud'));
    expect(js, contains('MutationObserver'));
    expect(js, contains('isle-sk-revealed'));
    expect(js, contains('requestAnimationFrame'));
    expect(js, isNot(contains('setTimeout(apply, 80)')));
  });

  test('searchQueryFromUrl parses google q param', () {
    expect(
      SafariWebConfig.searchQueryFromUrl(
        'https://www.google.com/search?q=starcraft+2&safe=active',
      ),
      'starcraft 2',
    );
    expect(
      SafariWebConfig.isGoogleSearchUrl('https://www.google.com/'),
      isFalse,
    );
  });
}
