import 'package:flutter/material.dart';

import '../../features/home/presentation/widgets/schedule_block_detail_sheet.dart';
import '../block_schedule/schedule_target_access_guard.dart';
import '../explorer/explorer_site.dart';
import '../explorer/isle_platform.dart';
import '../guard/isle_content_block_guard.dart';
import 'share_link_router.dart';

/// 플랫폼 피커·공유 링크 — 스케줄·한도·웹사이트·채널 차단 진입 차단 (동기 검사)
class ExplorerEntryGuard {
  ExplorerEntryGuard._();

  static String? denyMessageForSite(
    ExplorerSite site, {
    String? url,
    bool inAppExplorer = true,
  }) {
    return IsleContentBlockGuard.denyExplorerEntry(
      isYoutubeSite: site.isYoutube,
      isInstagramSite: site.isInstagram,
      isBrunchSite: site.isBrunch,
      isCustomSite: site == ExplorerSite.custom,
      url: url ?? _defaultUrlForSite(site),
      inAppExplorer: inAppExplorer,
    );
  }

  static String? denyMessageForPlatform(
    IslePlatform platform, {
    String? url,
    bool inAppExplorer = true,
  }) =>
      denyMessageForSite(platform.site, url: url ?? platform.homeUrl, inAppExplorer: inAppExplorer);

  static String? denyMessageForShareUrl(String raw) {
    final contentDeny = IsleContentBlockGuard.denyUrl(raw, inAppExplorer: false);
    if (contentDeny != null) return contentDeny;

    final route = ShareLinkRouter.inAppRouteForUrl(raw);
    if (route == null) return null;

    if (route.startsWith('/youtube/podcast') ||
        route.startsWith('/youtube-focus') ||
        route.contains('/youtube/browser') ||
        route.contains('site=youtube')) {
      if (ScheduleTargetAccessGuard.isIsleYoutubeBlocked) {
        return '스케줄로 Isle · YouTube가 차단 중이에요';
      }
    }
    if (route.contains('site=instagram')) {
      return denyMessageForSite(ExplorerSite.instagram, url: raw, inAppExplorer: true);
    }
    if (route.contains('site=brunch')) {
      return denyMessageForSite(ExplorerSite.brunch, url: raw, inAppExplorer: true);
    }
    if (route.contains('site=facebook')) {
      return denyMessageForSite(ExplorerSite.facebook, url: raw, inAppExplorer: true);
    }
    if (route.startsWith('/explore/browser') || route.startsWith('/viewer')) {
      return IsleContentBlockGuard.denyUrl(raw, checkYoutubeLimit: false, inAppExplorer: true);
    }
    return null;
  }

  static bool showDenial(
    BuildContext context,
    String message, {
    String? url,
    ExplorerSite? site,
    bool inAppExplorer = true,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 9),
        action: SnackBarAction(
          label: '더보기',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            showScheduleBlockDetailSheet(
              context,
              url: url,
              site: site,
              previewMessage: message,
              inAppExplorer: inAppExplorer,
            );
          },
        ),
      ),
    );
    return false;
  }

  static bool allowOrSnack(
    BuildContext context,
    String? message, {
    String? url,
    ExplorerSite? site,
    bool inAppExplorer = true,
  }) {
    if (message == null) return true;
    return showDenial(
      context,
      message,
      url: url,
      site: site,
      inAppExplorer: inAppExplorer,
    );
  }

  static String? _defaultUrlForSite(ExplorerSite site) {
    for (final p in PlatformCatalog.platforms) {
      if (p.site == site) return p.homeUrl;
    }
    if (site == ExplorerSite.facebook) return 'https://m.facebook.com/';
    return null;
  }
}
