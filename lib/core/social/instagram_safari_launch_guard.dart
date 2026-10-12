import '../block_schedule/schedule_target_access_guard.dart';
import '../library/platform_watch_limit_store.dart';

/// 인앱/외부 Safari로 Instagram 우회 방지 (로그인 후 피드·DM 무제한 접근)
class InstagramSafariLaunchGuard {
  InstagramSafariLaunchGuard._();

  static String? denyBrowsingEscape() {
    if (ScheduleTargetAccessGuard.isIsleInstagramBlocked) {
      return '스케줄로 Isle · Instagram이 차단 중이에요';
    }
    if (ScheduleTargetAccessGuard.isIsleInstagramDmBlocked) {
      return '스케줄로 Isle · Instagram DM이 차단 중이에요';
    }
    if (PlatformWatchLimitStore.isEnabled(PlatformWatchId.instagram) &&
        PlatformWatchLimitStore.isLimitReached(PlatformWatchId.instagram)) {
      return '오늘 Instagram 피드 한도에 도달했어요 · DM은 앱에서 계속 가능';
    }
    return null;
  }

  static bool get isEscapeBlocked => denyBrowsingEscape() != null;

  static bool redirectsToInstagram(String raw) {
    var url = raw.trim().toLowerCase();
    if (url.isEmpty) return false;
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host;
    return host == 'instagram.com' ||
        host.endsWith('.instagram.com') ||
        host == 'instagr.am';
  }

  static String? denyLaunchUrl(String url) {
    if (!redirectsToInstagram(url)) return null;
    return denyBrowsingEscape();
  }
}
