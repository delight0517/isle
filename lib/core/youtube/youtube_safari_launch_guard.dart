import '../block_schedule/schedule_target_access_guard.dart';
import 'youtube_access_guard.dart';
import 'youtube_limit_gate.dart';
import 'youtube_url_redirect.dart';

/// 인앱/외부 Safari로 YouTube 시청 우회 방지 (로그인 후 youtube.com 리다이렉트 포함)
class YoutubeSafariLaunchGuard {
  YoutubeSafariLaunchGuard._();

  static String? denyBrowsingEscape() {
    if (ScheduleTargetAccessGuard.isIsleYoutubeBlocked) {
      return '스케줄로 Isle · YouTube가 차단 중이에요';
    }
    if (YoutubeAccessGuard.shouldBlockWebView) {
      return YoutubeLimitGate.blockedTitle(
        YoutubeAccessGuard.activeLock() ?? YoutubeLockReason.dailyLimit,
      );
    }
    return null;
  }

  static bool get isEscapeBlocked => denyBrowsingEscape() != null;

  /// Google 로그인 완료 후 youtube.com으로 이어지는 URL
  static bool redirectsToYoutube(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return false;
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    if (YoutubeUrlRedirect.isYoutubeUrl(url)) return true;

    final host = uri.host.toLowerCase();
    if (!host.contains('google')) return false;
    if (uri.queryParameters['service']?.toLowerCase() == 'youtube') return true;
    final cont = uri.queryParameters['continue'] ?? '';
    return cont.isNotEmpty && YoutubeUrlRedirect.isYoutubeUrl(cont);
  }

  static String? denyLaunchUrl(String url) {
    if (!isYoutubeAuthOrBrowseUrl(url)) return null;
    return denyBrowsingEscape();
  }

  /// YouTube 시청·Google 로그인(패스키·비밀번호) — Safari 우회면 전부 차단
  static bool isYoutubeAuthOrBrowseUrl(String raw) {
    if (redirectsToYoutube(raw)) return true;
    var url = raw.trim();
    if (url.isEmpty) return false;
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (!host.contains('google')) return false;
    final path = uri.path.toLowerCase();
    if (path.contains('servicelogin') ||
        path.contains('/signin') ||
        path.contains('/challenge') ||
        path.contains('passkey') ||
        path.contains('webauthn')) {
      return true;
    }
    return host.contains('accounts.google');
  }
}
