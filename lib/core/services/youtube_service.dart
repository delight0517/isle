import '../utils/url_parser.dart';

/// YouTube URL/메타 관련 Phase 1 헬퍼
class YoutubeService {
  YoutubeService._();

  static String? videoIdFromUrl(String url) => UrlParser.extractYouTubeVideoId(url);

  static String thumbnailForUrl(String url) {
    final id = videoIdFromUrl(url);
    if (id == null) return '';
    return UrlParser.youTubeThumbnail(id);
  }
}
