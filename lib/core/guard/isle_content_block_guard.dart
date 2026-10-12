import '../explorer/explorer_site.dart';
import '../safe_browser/safe_browser_temporary_allow_store.dart';
import '../youtube/youtube_link_canonical.dart';
import 'in_app_safari_host.dart';
import 'isle_block_boundary.dart';

/// 차단 채널·URL·키워드·웹사이트·한도 — [IsleBlockBoundary] 경유 (표면별 계층 분리)
class IsleContentBlockGuard {
  IsleContentBlockGuard._();

  /// null이면 허용
  static String? denyUrl(
    String raw, {
    bool checkYoutubeLimit = true,
    bool inAppExplorer = false,
    ExplorerSite? explorerSite,
  }) {
    var url = raw.trim();
    if (url.isEmpty) return null;
    if (!url.startsWith('http')) url = 'https://$url';
    url = YoutubeLinkCanonical.normalizeForBlockCheck(url);

    final site = explorerSite ??
        (inAppExplorer ? ExplorerSite.youtube : ExplorerSite.custom);

    if (site == ExplorerSite.custom) {
      final uri = Uri.tryParse(url);
      if (SafeBrowserTemporaryAllowStore.isAllowed(uri?.host)) {
        return null;
      }
    }

    return IsleBlockBoundary.denyNavigation(
      site: site,
      url: url,
      checkWatchLimit: checkYoutubeLimit,
    );
  }

  /// 인앱 Safari(site=custom)
  static String? denyInAppSafariNavigation(String raw) =>
      denyUrl(raw, inAppExplorer: true, explorerSite: ExplorerSite.custom);

  static ExplorerSite scheduleOverlaySiteForCustomUrl(String url) =>
      InAppSafariHostResolver.explorerSiteFor(InAppSafariHostResolver.hostForUrl(url));

  static String? denyExplorerEntry({
    required bool isYoutubeSite,
    required bool isInstagramSite,
    required bool isBrunchSite,
    required bool isCustomSite,
    String? url,
    bool inAppExplorer = true,
  }) {
    final site = isYoutubeSite
        ? ExplorerSite.youtube
        : isInstagramSite
            ? ExplorerSite.instagram
            : isBrunchSite
                ? ExplorerSite.brunch
                : ExplorerSite.custom;
    return IsleBlockBoundary.denyEntry(site: site, url: url);
  }
}
