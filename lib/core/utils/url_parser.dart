import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

class UrlParser {
  static final _dio = Dio();

  static String detectSourceType(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) return 'youtube';
    if (url.contains('brunch.co.kr')) return 'brunch';
    return 'article';
  }

  static String? extractYouTubePlaylistId(String url) {
    final m = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)').firstMatch(url);
    return m?.group(1);
  }

  static bool isWatchLaterPlaylist(String url) {
    final id = extractYouTubePlaylistId(url);
    return id == 'WL' || id == 'watchlater' || url.contains('playlist?list=WL');
  }

  static String? extractYouTubeVideoId(String url) {
    final patterns = [
      RegExp(r'(?:youtube\.com|music\.youtube\.com)/watch\?v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  static String youTubeThumbnail(String videoId) =>
      'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';

  /// URL에서 og:title, og:image 메타 추출
  static Future<UrlMeta> fetchMeta(String url) async {
    try {
      final res = await _dio.get(
        url,
        options: Options(
          headers: {'User-Agent': 'Mozilla/5.0'},
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final doc = html_parser.parse(res.data as String);
      final title = doc.querySelector('meta[property="og:title"]')?.attributes['content'] ??
          doc.querySelector('title')?.text ??
          url;
      var thumb = doc.querySelector('meta[property="og:image"]')?.attributes['content'];
      final yt = extractYouTubeVideoId(url);
      if (yt != null && (thumb?.trim().isEmpty ?? true)) {
        thumb = youTubeThumbnail(yt);
      }
      return UrlMeta(title: title.trim(), thumbnailUrl: thumb);
    } catch (_) {
      final yt = extractYouTubeVideoId(url);
      return UrlMeta(
        title: url,
        thumbnailUrl: yt != null ? youTubeThumbnail(yt) : null,
      );
    }
  }
}

class UrlMeta {
  final String title;
  final String? thumbnailUrl;
  const UrlMeta({required this.title, this.thumbnailUrl});
}
