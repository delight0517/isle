import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/explorer/google_search_youtube_preview_block_script.dart';

void main() {
  test('google youtube preview block script targets SERP embeds', () {
    expect(GoogleSearchYoutubePreviewBlockScript.install, contains('isGoogleSearch'));
    expect(GoogleSearchYoutubePreviewBlockScript.install, contains('youtube.com'));
    expect(GoogleSearchYoutubePreviewBlockScript.install, contains('iframe'));
    expect(GoogleSearchYoutubePreviewBlockScript.install, contains('MutationObserver'));
  });
}
