import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/youtube/block_keyword_policy.dart';

void main() {
  test('platform noise keywords stripped', () {
    expect(
      BlockKeywordPolicy.sanitizeStoredKeywords(['starcraft', 'youtube', 'pornhub']),
      ['starcraft', 'pornhub'],
    );
  });

  test('youtube.com removed from website block domains', () {
    expect(
      BlockKeywordPolicy.sanitizeStoredWebsiteDomains(['mingky.net', 'youtube.com']),
      ['mingky.net'],
    );
  });

  test('keyword does not match youtube home url', () {
    expect(
      BlockKeywordPolicy.keywordInYoutubeUrl(
        'https://m.youtube.com/',
        const ['youtube', 'gaming'],
      ),
      isNull,
    );
  });

  test('broad youtube noise stripped from stored keywords', () {
    expect(
      BlockKeywordPolicy.sanitizeStoredKeywords([
        'starcraft',
        'shorts',
        'asmr',
        'pornhub',
        'video',
      ]),
      ['starcraft', 'pornhub'],
    );
  });

  test('forYoutubeInject caps keyword count', () {
    final many = List.generate(120, (i) => 'uniquekeyword$i');
    expect(BlockKeywordPolicy.forYoutubeInject(many).length, 96);
  });

  test('keyword matches search query path only', () {
    expect(
      BlockKeywordPolicy.keywordInYoutubeUrl(
        'https://www.youtube.com/results?search_query=starcraft',
        const ['starcraft'],
      ),
      'starcraft',
    );
  });
}
