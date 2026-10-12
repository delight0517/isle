import '../utils/url_parser.dart';

/// 차단·진입 검사 전 URL 정규화 (리다이렉트·music.youtube 등)
class YoutubeLinkCanonical {
  YoutubeLinkCanonical._();

  static String normalizeForBlockCheck(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http')) url = 'https://$url';
    url = _unwrapRedirectChain(url);

    final vid = UrlParser.extractYouTubeVideoId(url);
    if (vid != null) {
      final uri = Uri.tryParse(url);
      final channelId =
          uri?.queryParameters['channel_id'] ?? uri?.queryParameters['uc'];
      if (channelId != null && channelId.trim().isNotEmpty) {
        return 'https://www.youtube.com/watch?v=$vid&channel_id=${Uri.encodeComponent(channelId.trim())}';
      }
      return 'https://www.youtube.com/watch?v=$vid';
    }
    return url.split('#').first;
  }

  static String _unwrapRedirectChain(String url) {
    var current = url;
    for (var i = 0; i < 4; i++) {
      final next = _unwrapOnce(current);
      if (next == current) break;
      current = next;
    }
    return current;
  }

  static String _unwrapOnce(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host.toLowerCase();

    if (host.contains('google.') && uri.path.contains('/url')) {
      for (final key in ['q', 'url', 'u']) {
        final target = uri.queryParameters[key];
        if (target != null && target.startsWith('http')) {
          return Uri.decodeComponent(target);
        }
      }
    }
    if (host.contains('facebook.com') && uri.path.contains('l.php')) {
      final target = uri.queryParameters['u'];
      if (target != null && target.startsWith('http')) {
        return Uri.decodeComponent(target);
      }
    }
    return url;
  }
}
