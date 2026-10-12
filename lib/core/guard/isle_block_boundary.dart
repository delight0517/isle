import '../block_schedule/schedule_target_access_guard.dart';
import '../block_schedule/url_rules/schedule_web_block_guard.dart';
import '../explorer/explorer_site.dart';
import '../intervention/website_block_guard.dart';
import '../library/platform_watch_limit_store.dart';
import '../safety/content_safety_guard.dart';
import '../social/instagram_safari_launch_guard.dart';
import '../youtube/blocked_channel_store.dart';
import '../youtube/blocked_url_guard.dart';
import '../youtube/blocked_url_store.dart';
import '../youtube/content_filter_store.dart';
import '../youtube/youtube_access_guard.dart';
import '../youtube/youtube_channel_block_guard.dart';
import '../youtube/youtube_limit_gate.dart';
import '../youtube/youtube_link_canonical.dart';
import '../youtube/youtube_safari_launch_guard.dart';
import '../youtube/youtube_url_redirect.dart';
import 'in_app_safari_host.dart';

/// Isle **내부 앱 표면** — 서로 다른 WebView·진입점
enum IsleAppSurface {
  /// `/youtube/browser` · `ExplorerSite.youtube`
  youtubeDedicated,

  /// custom Safari 안 youtube.com
  youtubeInSafari,

  /// `ExplorerSite.instagram`
  instagramDedicated,

  /// custom Safari 안 instagram.com
  instagramInSafari,

  /// `ExplorerSite.brunch`
  brunchDedicated,

  /// custom Safari 안 brunch
  brunchInSafari,

  /// custom Safari — 일반 웹
  safariGeneric,

  /// 공유·외부 브라우저
  externalLink,
}

/// 차단 **계층** — 한 표면에 모두 적용되지 않음
enum BlockLayer {
  /// ③ Isle 유튜브·인스타 등 스케줄 타깃
  scheduleTarget,

  /// 일일·주기 시청 한도
  watchLimit,

  /// 스케줄 도메인·URL 규칙 (Safari·OS용)
  scheduleDomain,

  /// 항상 차단 웹사이트 목록
  websiteAlways,

  /// 채널·키워드·영상 (주로 YouTube)
  contentFilter,

  /// 사용자 URL 블록리스트
  urlBlocklist,

  /// 성인·안전 모드
  safety,

  /// Safari로 시청 우회 (Google 로그인 → youtube 등)
  safariEscape,
}

/// 표면별 적용 계층 — **단일 출처**. 새 차단 기능은 여기부터.
abstract final class IsleBlockBoundary {
  IsleBlockBoundary._();

  static const _policy = <IsleAppSurface, Set<BlockLayer>>{
    IsleAppSurface.youtubeDedicated: {
      BlockLayer.scheduleTarget,
      BlockLayer.watchLimit,
      BlockLayer.contentFilter,
      BlockLayer.urlBlocklist,
      BlockLayer.safety,
      BlockLayer.websiteAlways,
    },
    IsleAppSurface.youtubeInSafari: {
      BlockLayer.scheduleTarget,
      BlockLayer.watchLimit,
      BlockLayer.scheduleDomain,
      BlockLayer.websiteAlways,
      BlockLayer.contentFilter,
      BlockLayer.urlBlocklist,
      BlockLayer.safety,
      BlockLayer.safariEscape,
    },
    IsleAppSurface.instagramDedicated: {
      BlockLayer.scheduleTarget,
      BlockLayer.watchLimit,
      BlockLayer.urlBlocklist,
      BlockLayer.safety,
      BlockLayer.websiteAlways,
    },
    IsleAppSurface.instagramInSafari: {
      BlockLayer.scheduleTarget,
      BlockLayer.watchLimit,
      BlockLayer.scheduleDomain,
      BlockLayer.websiteAlways,
      BlockLayer.urlBlocklist,
      BlockLayer.safety,
      BlockLayer.safariEscape,
    },
    IsleAppSurface.brunchDedicated: {
      BlockLayer.scheduleTarget,
      BlockLayer.watchLimit,
      BlockLayer.urlBlocklist,
      BlockLayer.safety,
      BlockLayer.websiteAlways,
    },
    IsleAppSurface.brunchInSafari: {
      BlockLayer.scheduleTarget,
      BlockLayer.watchLimit,
      BlockLayer.scheduleDomain,
      BlockLayer.websiteAlways,
      BlockLayer.urlBlocklist,
      BlockLayer.safety,
    },
    IsleAppSurface.safariGeneric: {
      BlockLayer.scheduleTarget,
      BlockLayer.scheduleDomain,
      BlockLayer.websiteAlways,
      BlockLayer.urlBlocklist,
      BlockLayer.safety,
      BlockLayer.safariEscape,
    },
    IsleAppSurface.externalLink: {
      BlockLayer.scheduleDomain,
      BlockLayer.websiteAlways,
      BlockLayer.urlBlocklist,
      BlockLayer.safety,
      BlockLayer.contentFilter,
      BlockLayer.safariEscape,
      BlockLayer.watchLimit,
      BlockLayer.scheduleTarget,
    },
  };

  static IsleAppSurface surfaceFor({
    required ExplorerSite site,
    String? url,
  }) {
    if (site == ExplorerSite.youtube) return IsleAppSurface.youtubeDedicated;
    if (site == ExplorerSite.instagram) return IsleAppSurface.instagramDedicated;
    if (site == ExplorerSite.brunch) return IsleAppSurface.brunchDedicated;
    if (site == ExplorerSite.custom) {
      return switch (InAppSafariHostResolver.hostForUrl(url)) {
        InAppSafariHost.youtube => IsleAppSurface.youtubeInSafari,
        InAppSafariHost.instagram => IsleAppSurface.instagramInSafari,
        InAppSafariHost.brunch => IsleAppSurface.brunchInSafari,
        _ => IsleAppSurface.safariGeneric,
      };
    }
    return IsleAppSurface.safariGeneric;
  }

  static bool appliesLayer(IsleAppSurface surface, BlockLayer layer) =>
      _policy[surface]?.contains(layer) ?? false;

  static bool appliesScheduleDomainShield(ExplorerSite site, {String? url}) =>
      appliesLayer(surfaceFor(site: site, url: url), BlockLayer.scheduleDomain);

  /// 화면 **진입** — WebView 띄우기 전
  static String? denyEntry({
    required ExplorerSite site,
    String? url,
  }) {
    final surface = surfaceFor(site: site, url: url);
    return _deny(surface: surface, url: url ?? site.defaultHomeUrl, entry: true);
  }

  /// WebView **네비게이션** — URL 이동 시
  static String? denyNavigation({
    required ExplorerSite site,
    required String url,
    bool checkWatchLimit = true,
  }) {
    final surface = surfaceFor(site: site, url: url);
    return _deny(
      surface: surface,
      url: url,
      entry: false,
      checkWatchLimit: checkWatchLimit,
    );
  }

  /// 공유·외부 링크
  static String? denyExternalUrl(String raw) {
    return _deny(surface: IsleAppSurface.externalLink, url: raw, entry: true);
  }

  static String? _deny({
    required IsleAppSurface surface,
    required String? url,
    required bool entry,
    bool checkWatchLimit = true,
  }) {
    var u = url?.trim() ?? '';
    if (u.isEmpty) {
      if (entry) return _denyScheduleTargetOnly(surface);
      return null;
    }
    if (!u.startsWith('http')) u = 'https://$u';
    u = YoutubeLinkCanonical.normalizeForBlockCheck(u);

    if (entry) {
      final target = _denyScheduleTarget(surface);
      if (target != null) return target;
    }

    if (appliesLayer(surface, BlockLayer.safariEscape)) {
      final esc = _denySafariEscape(u);
      if (esc != null) return esc;
    }

    if (appliesLayer(surface, BlockLayer.safety)) {
      final safety = ContentSafetyGuard.matchUrl(u);
      if (safety != null) return safety.snackMessage;
    }

    if (appliesLayer(surface, BlockLayer.websiteAlways)) {
      final web = WebsiteBlockGuard.matchUrl(u);
      if (web != null) return web.snackMessage;
    }

    if (appliesLayer(surface, BlockLayer.scheduleDomain)) {
      final sched = ScheduleWebBlockGuard.matchUrl(u);
      if (sched != null) return sched.snackMessage;
    }

    if (appliesLayer(surface, BlockLayer.urlBlocklist)) {
      final urlHit = BlockedUrlGuard.match(u, BlockedUrlStore.loadAll());
      if (urlHit != null) return urlHit.snackMessage;
    }

    final isYt = YoutubeUrlRedirect.isYoutubeUrl(u);
    if (isYt && appliesLayer(surface, BlockLayer.contentFilter)) {
      final yt = YoutubeChannelBlockGuard.matchUrl(
        u,
        channels: BlockedChannelStore.loadAll(),
        videos: ContentFilterStore.loadVideos(),
        keywords: _keywords(),
        blockedUrls: BlockedUrlStore.loadAll(),
      );
      if (yt != null) return yt.snackMessage;
    }

    if (checkWatchLimit && appliesLayer(surface, BlockLayer.watchLimit)) {
      final limit = _denyWatchLimit(surface, u);
      if (limit != null) return limit;
    }

    return null;
  }

  static String? _denyScheduleTargetOnly(IsleAppSurface surface) {
    return _denyScheduleTarget(surface);
  }

  static String? _denyScheduleTarget(IsleAppSurface surface) {
    if (!appliesLayer(surface, BlockLayer.scheduleTarget)) return null;
    return switch (surface) {
      IsleAppSurface.youtubeDedicated || IsleAppSurface.youtubeInSafari =>
        ScheduleTargetAccessGuard.isIsleYoutubeBlocked
            ? '스케줄로 Isle · YouTube가 차단 중이에요'
            : null,
      IsleAppSurface.instagramDedicated || IsleAppSurface.instagramInSafari =>
        ScheduleTargetAccessGuard.isIsleInstagramBlocked
            ? '스케줄로 Isle · Instagram이 차단 중이에요'
            : null,
      IsleAppSurface.brunchDedicated || IsleAppSurface.brunchInSafari =>
        ScheduleTargetAccessGuard.isIsleBrunchBlocked
            ? '스케줄로 Isle · Brunch가 차단 중이에요'
            : null,
      IsleAppSurface.safariGeneric =>
        ScheduleTargetAccessGuard.isIsleCustomWebBlocked
            ? '스케줄로 Isle · 웹 탐색이 차단 중이에요'
            : null,
      IsleAppSurface.externalLink => null,
    };
  }

  static String? _denySafariEscape(String url) {
    final yt = YoutubeSafariLaunchGuard.denyLaunchUrl(url);
    if (yt != null) return '$yt · Safari·인앱 브라우저';
    final ig = InstagramSafariLaunchGuard.denyLaunchUrl(url);
    if (ig != null) return '$ig · Safari·인앱 브라우저';
    return null;
  }

  static String? _denyWatchLimit(IsleAppSurface surface, String url) {
    if (surface == IsleAppSurface.youtubeDedicated ||
        surface == IsleAppSurface.youtubeInSafari) {
      if (!YoutubeAccessGuard.shouldBlockWebView) return null;
      return YoutubeLimitGate.blockedTitle(
        YoutubeAccessGuard.activeLock() ?? YoutubeLockReason.dailyLimit,
      );
    }
    if (surface == IsleAppSurface.instagramDedicated ||
        surface == IsleAppSurface.instagramInSafari) {
      if (!PlatformWatchLimitStore.isEnabled(PlatformWatchId.instagram)) {
        return null;
      }
      if (!PlatformWatchLimitStore.isLimitReached(PlatformWatchId.instagram)) {
        return null;
      }
      return 'Instagram 시청 한도에 도달했어요';
    }
    return null;
  }

  static List<String> _keywords() {
    final user = ContentFilterStore.loadKeywords();
    if (!ContentSafetyGuard.enabled) return user;
    return {...user, ...ContentSafetyGuard.builtInYoutubeKeywords}.toList();
  }
}
