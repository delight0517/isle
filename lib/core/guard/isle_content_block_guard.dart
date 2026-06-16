import '../block_schedule/schedule_target_access_guard.dart';
import '../block_schedule/url_rules/schedule_web_block_guard.dart';
import '../intervention/website_block_guard.dart';
import '../safety/content_safety_guard.dart';
import '../youtube/blocked_channel_store.dart';
import '../youtube/blocked_url_guard.dart';
import '../youtube/blocked_url_store.dart';
import '../youtube/content_filter_store.dart';
import '../youtube/youtube_access_guard.dart';
import '../youtube/youtube_channel_block_guard.dart';
import '../youtube/youtube_limit_gate.dart';
import '../youtube/youtube_url_redirect.dart';

/// 차단 채널·URL·키워드·웹사이트·한도 — 앱·외부 브라우저·공유 진입 공통
class IsleContentBlockGuard {
  IsleContentBlockGuard._();

  /// null이면 허용
  /// [inAppExplorer] true — 스케줄 도메인 쉴드는 Safari용만 (인앱은 Isle 타깃·한도)
  static String? denyUrl(
    String raw, {
    bool checkYoutubeLimit = true,
    bool inAppExplorer = false,
  }) {
    var url = raw.trim();
    if (url.isEmpty) return null;
    if (!url.startsWith('http')) url = 'https://$url';

    final safety = ContentSafetyGuard.matchUrl(url);
    if (safety != null) return safety.snackMessage;

    final web = WebsiteBlockGuard.matchUrl(url);
    if (web != null) return '${web.snackMessage} · 외부 브라우저도 막혀 있어요';

    if (!inAppExplorer) {
      final scheduleWeb = ScheduleWebBlockGuard.matchUrl(url);
      if (scheduleWeb != null) {
        return '${scheduleWeb.snackMessage} · 외부 브라우저도 막혀 있어요';
      }
    }

    final blockedUrls = BlockedUrlStore.loadAll();
    final urlHit = BlockedUrlGuard.match(url, blockedUrls);
    if (urlHit != null) return urlHit.snackMessage;

    final isYt = YoutubeUrlRedirect.isYoutubeUrl(url);
    if (isYt) {
      final yt = YoutubeChannelBlockGuard.matchUrl(
        url,
        channels: BlockedChannelStore.loadAll(),
        videos: ContentFilterStore.loadVideos(),
        keywords: _keywords(),
        blockedUrls: blockedUrls,
      );
      if (yt != null) return yt.snackMessage;

      if (checkYoutubeLimit && YoutubeAccessGuard.shouldBlockWebView) {
        return YoutubeLimitGate.blockedTitle(
          YoutubeAccessGuard.activeLock() ?? YoutubeLockReason.dailyLimit,
        );
      }
    }
    return null;
  }

  /// ExplorerSite + URL — 스케줄·콘텐츠 통합
  static String? denyExplorerEntry({
    required bool isYoutubeSite,
    required bool isInstagramSite,
    required bool isBrunchSite,
    required bool isCustomSite,
    String? url,
    bool inAppExplorer = true,
  }) {
    if (isYoutubeSite) {
      if (ScheduleTargetAccessGuard.isIsleYoutubeBlocked) {
        return '스케줄로 Isle · YouTube가 차단 중이에요';
      }
    } else if (isInstagramSite) {
      if (ScheduleTargetAccessGuard.isIsleInstagramBlocked) {
        return '스케줄로 Isle · Instagram이 차단 중이에요';
      }
    } else if (isBrunchSite) {
      if (ScheduleTargetAccessGuard.isIsleBrunchBlocked) {
        return '스케줄로 Isle · Brunch가 차단 중이에요';
      }
    } else if (isCustomSite) {
      if (ScheduleTargetAccessGuard.isIsleCustomWebBlocked) {
        return '스케줄로 Isle · 웹 탐색이 차단 중이에요';
      }
    }
    if (url != null && url.trim().isNotEmpty) {
      return denyUrl(url, inAppExplorer: inAppExplorer);
    }
    return null;
  }

  static List<String> _keywords() {
    final user = ContentFilterStore.loadKeywords();
    if (!ContentSafetyGuard.enabled) return user;
    return {
      ...user,
      ...ContentSafetyGuard.builtInYoutubeKeywords,
    }.toList();
  }
}
