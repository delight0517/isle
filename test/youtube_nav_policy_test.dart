import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/youtube/youtube_nav_policy.dart';

void main() {
  test('search results are browse surface not watch', () {
    const url = 'https://m.youtube.com/results?search_query=flutter';
    expect(YoutubeNavPolicy.isSearchResultsUrl(url), isTrue);
    expect(YoutubeNavPolicy.isWatchUrl(url), isFalse);
    expect(YoutubeNavPolicy.isBrowseSurface(url), isTrue);
  });

  test('watch url is not browse surface', () {
    const url = 'https://m.youtube.com/watch?v=dQw4w9WgXcQ';
    expect(YoutubeNavPolicy.isWatchUrl(url), isTrue);
    expect(YoutubeNavPolicy.isBrowseSurface(url), isFalse);
  });
}
