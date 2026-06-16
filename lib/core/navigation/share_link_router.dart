import '../services/isle_user_defaults.dart';
import '../youtube/youtube_clipboard_watch.dart';
import '../youtube/youtube_music_route.dart';
import '../youtube/youtube_focus_clipboard.dart';

/// 공유·딥링크 URL → 앱 내 적절한 화면
class ShareLinkRouter {
  ShareLinkRouter._();

  /// `app_links` · `isle://youtube?url=` · https YouTube
  static String? routeFromIncomingUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'isle') {
      final host = uri.host.toLowerCase();
      if (host == 'playlist') {
        final payload = uri.queryParameters['data']?.trim();
        if (payload != null && payload.isNotEmpty) {
          return '/home/share/playlists/import?data=${Uri.encodeComponent(payload)}';
        }
      }
      if (host == 'youtube' || host == 'open') {
        final q = uri.queryParameters['url']?.trim();
        if (q != null && q.isNotEmpty) return inAppRouteForUrl(q);
      }
      if (host == 'login-callback') return null;
      return null;
    }
    if (scheme == 'http' || scheme == 'https') {
      // 기본 브라우저로 들어온 임의 URL(QR·타앱 링크)은 필터·차단 오버레이가
      // 있는 인앱 브라우저에서 연다 (passive 뷰어 아님 — 차단 목적).
      return inAppRouteForUrl(uri.toString(), preferBrowser: true);
    }
    return null;
  }

  /// KakaoTalk·Safari 공유 → 저장·플레이리스트·아카이브 선택 화면
  static String quickSaveRouteForUrl(String raw) {
    var url = raw.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    return '/home/share/quick-save?url=${Uri.encodeComponent(url)}';
  }

  /// go_router path + query (leading `/` 포함)
  ///
  /// [preferBrowser] true면 미지정 호스트(유튜브·인스타 등 특수 처리 외)를
  /// passive 뷰어 대신 필터·차단되는 인앱 브라우저(`site=custom`)로 보낸다.
  /// 기본 브라우저 진입(QR·타앱 링크)에서 사용.
  static String? inAppRouteForUrl(String raw, {bool preferBrowser = false}) {
    var url = raw.trim();
    if (url.isEmpty) return null;
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      final normalized = YoutubeClipboardWatch.normalizeUrl(url);
      if (normalized != null) {
        final podcastRoute = YoutubeMusicRoute.podcastRouteFor(normalized);
        if (podcastRoute != null) return podcastRoute;
        if (IsleUserDefaults.youtubeSharesUsePodcastMode) {
          return '/youtube/podcast?url=${Uri.encodeComponent(normalized)}';
        }
        if (IsleUserDefaults.youtubeSharesUseFocusMode) {
          final id = YoutubeFocusClipboard.videoIdFromUrl(normalized);
          if (id != null) return '/youtube-focus/watch/$id';
        }
        return '/youtube/browser?url=${Uri.encodeComponent(normalized)}';
      }
    }
    if (host.contains('instagram.com')) {
      return '/explore/browser?site=instagram&url=${Uri.encodeComponent(url)}';
    }
    if (host.contains('brunch.co.kr')) {
      return '/explore/browser?site=brunch&url=${Uri.encodeComponent(url)}';
    }
    if (host.contains('facebook.com') || host.contains('fb.com')) {
      return '/explore/browser?site=facebook&url=${Uri.encodeComponent(url)}';
    }
    if (preferBrowser) {
      return '/explore/browser?site=custom&url=${Uri.encodeComponent(url)}';
    }
    return '/viewer?url=${Uri.encodeComponent(url)}&title=';
  }
}
