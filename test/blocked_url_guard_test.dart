import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/explorer/google_surface_url_block_script.dart';
import 'package:isle/core/youtube/blocked_url_guard.dart';
import 'package:isle/core/youtube/models/blocked_url.dart';

void main() {
  test('blocked url guard matches canonical youtube url', () {
    final entries = [
      BlockedUrl(
        canonicalUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        youtubeVideoId: 'dQw4w9WgXcQ',
        blockedAt: DateTime.utc(2026, 1, 1),
      ),
    ];
    final hit = BlockedUrlGuard.match(
      'https://m.youtube.com/watch?v=dQw4w9WgXcQ&utm_source=x',
      entries,
    );
    expect(hit, isNotNull);
  });

  test('google surface url block script builds', () {
    expect(
      GoogleSurfaceUrlBlockScript.build(['https://example.com/article']),
      contains('blockedUrls'),
    );
  });
}
