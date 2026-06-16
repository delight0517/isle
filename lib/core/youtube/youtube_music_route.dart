import '../services/isle_user_defaults.dart';
import '../utils/url_parser.dart';
import 'youtube_clipboard_watch.dart';

/// YouTube Music URL · 플레이리스트 → 음성 모드 라우팅 (영상 한도 회피)
class YoutubeMusicRoute {
  YoutubeMusicRoute._();

  static bool isMusicHost(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    var t = url.trim();
    if (!t.startsWith('http')) t = 'https://$t';
    final host = Uri.tryParse(t)?.host.toLowerCase() ?? '';
    if (host.contains('music.youtube')) return true;
    final path = Uri.tryParse(t)?.path.toLowerCase() ?? '';
    return path.startsWith('/music') || path.contains('/music/');
  }

  static bool shouldOpenPodcast(String url) {
    if (isMusicHost(url)) return true;
    if (UrlParser.extractYouTubePlaylistId(url) != null) return true;
    if (IsleUserDefaults.youtubeSharesUsePodcastMode &&
        UrlParser.extractYouTubeVideoId(url) != null) {
      return true;
    }
    return false;
  }

  static String? podcastRouteFor(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return null;
    if (!url.startsWith('http')) url = 'https://$url';
    final normalized = YoutubeClipboardWatch.normalizeUrl(url) ?? url;
    if (!shouldOpenPodcast(normalized)) return null;
    return '/youtube/podcast?url=${Uri.encodeComponent(normalized)}';
  }
}
