import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/youtube/block_keyword_policy.dart';

void main() {
  test('platform noise keywords stripped', () {
    expect(
      BlockKeywordPolicy.sanitizeStoredKeywords(['starcraft', 'youtube', 'pornhub']),
      ['starcraft', 'pornhub'],
    );
  });

  test('youtube.com allowed but subdomains removed from website block domains', () {
    // youtube.com 자체는 Safari Content Blocker 전용 경로라 허용한다(§8) —
    // 서브도메인 접미사 매칭으로 m.youtube.com 등도 자동 커버되므로, 개별
    // 서브도메인·googlevideo.com·youtu.be는 계속 걸러낸다.
    expect(
      BlockKeywordPolicy.sanitizeStoredWebsiteDomains(
        ['mingky.net', 'youtube.com', 'm.youtube.com', 'youtu.be', 'googlevideo.com'],
      ),
      ['mingky.net', 'youtube.com'],
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
