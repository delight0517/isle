import 'package:flutter/material.dart';

import '../../features/home/presentation/widgets/schedule_block_entry_sheet.dart';
import '../block_schedule/schedule_block_user_message.dart';
import '../block_schedule/schedule_target_access_guard.dart';
import '../explorer/explorer_site.dart';
import '../explorer/isle_platform.dart';
import '../guard/isle_block_boundary.dart';
import 'share_link_router.dart';

/// 플랫폼 피커·공유 링크 — [IsleBlockBoundary] 단일 진입
class ExplorerEntryGuard {
  ExplorerEntryGuard._();

  static String? denyMessageForSite(
    ExplorerSite site, {
    String? url,
    bool inAppExplorer = true,
  }) {
    final legacy = IsleBlockBoundary.denyEntry(site: site, url: url);
    if (legacy == null) return null;
    return ScheduleBlockUserMessage.shortDenial(
      site: site,
      url: url,
      legacyMessage: legacy,
    );
  }

  static String? denyMessageForPlatform(
    IslePlatform platform, {
    String? url,
    bool inAppExplorer = true,
  }) =>
      denyMessageForSite(platform.site, url: url ?? platform.homeUrl, inAppExplorer: inAppExplorer);

  static String? denyMessageForShareUrl(String raw) {
    final contentDeny = IsleBlockBoundary.denyExternalUrl(raw);
    if (contentDeny != null) {
      return ScheduleBlockUserMessage.shortDenial(url: raw, legacyMessage: contentDeny);
    }

    final route = ShareLinkRouter.inAppRouteForUrl(raw);
    if (route == null) return null;

    if (route.startsWith('/youtube/podcast') ||
        route.startsWith('/youtube-focus') ||
        route.contains('/youtube/browser') ||
        route.contains('site=youtube')) {
      if (ScheduleTargetAccessGuard.isIsleYoutubeBlocked) {
        return ScheduleBlockUserMessage.shortDenial(
          site: ExplorerSite.youtube,
          url: raw,
        );
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
      final uri = Uri.tryParse(route.startsWith('/') ? 'http://local$route' : route);
      final site = uri?.queryParameters['site'];
      if (site == 'custom' || (raw.startsWith('http') && route.contains('site=custom'))) {
        final legacy = IsleBlockBoundary.denyNavigation(
          site: ExplorerSite.custom,
          url: raw,
          checkWatchLimit: false,
        );
        if (legacy == null) return null;
        return ScheduleBlockUserMessage.shortDenial(
          site: ExplorerSite.custom,
          url: raw,
          legacyMessage: legacy,
        );
      }
      final legacy = IsleBlockBoundary.denyNavigation(
        site: ExplorerSite.youtube,
        url: raw,
        checkWatchLimit: false,
      );
      if (legacy == null) return null;
      return ScheduleBlockUserMessage.shortDenial(url: raw, legacyMessage: legacy);
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
    showScheduleBlockEntrySheet(
      context,
      site: site,
      url: url,
      legacyMessage: message,
      inAppExplorer: inAppExplorer,
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
}
