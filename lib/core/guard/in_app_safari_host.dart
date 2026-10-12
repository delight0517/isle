import '../block_schedule/schedule_target_access_guard.dart';
import '../explorer/explorer_site.dart';
import '../social/instagram_safari_launch_guard.dart';
import '../youtube/youtube_safari_launch_guard.dart';
import '../youtube/youtube_url_redirect.dart';

/// 인앱 Safari(custom WebView) 현재 URL — Isle 전용 탐색기와 동일 타깃·한도
enum InAppSafariHost { generic, youtube, instagram, brunch }

class InAppSafariHostResolver {
  InAppSafariHostResolver._();

  static InAppSafariHost hostForUrl(String? raw) {
    final url = raw?.trim() ?? '';
    if (url.isEmpty) return InAppSafariHost.generic;
    if (YoutubeUrlRedirect.isYoutubeUrl(url) ||
        YoutubeSafariLaunchGuard.isYoutubeAuthOrBrowseUrl(url)) {
      return InAppSafariHost.youtube;
    }
    if (InstagramSafariLaunchGuard.redirectsToInstagram(url)) {
      return InAppSafariHost.instagram;
    }
    if (url.contains('brunch.co.kr')) return InAppSafariHost.brunch;
    return InAppSafariHost.generic;
  }

  static ExplorerSite explorerSiteFor(InAppSafariHost host) => switch (host) {
        InAppSafariHost.youtube => ExplorerSite.youtube,
        InAppSafariHost.instagram => ExplorerSite.instagram,
        InAppSafariHost.brunch => ExplorerSite.brunch,
        InAppSafariHost.generic => ExplorerSite.custom,
      };

  static bool isScheduleTargetBlocked(InAppSafariHost host) => switch (host) {
        InAppSafariHost.youtube => ScheduleTargetAccessGuard.isIsleYoutubeBlocked,
        InAppSafariHost.instagram => ScheduleTargetAccessGuard.isIsleInstagramBlocked,
        InAppSafariHost.brunch => ScheduleTargetAccessGuard.isIsleBrunchBlocked,
        InAppSafariHost.generic => ScheduleTargetAccessGuard.isIsleCustomWebBlocked,
      };
}
