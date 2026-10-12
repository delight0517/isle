import 'dart:io' show Platform;

import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../block_schedule/url_rules/schedule_rule_enforcement.dart';
import '../brunch/brunch_blocked_author_store.dart';
import '../brunch/brunch_content_block_script.dart';
import '../intervention/website_block_store.dart';
import '../services/isle_user_defaults.dart';
import '../localization/locale_controller.dart';
import '../localization/web_locale_policy.dart';
import '../social/instagram_auth_path_policy.dart';
import '../social/instagram_dm_focus_script.dart';
import '../social/instagram_dm_navigation_script.dart';
import '../social/instagram_explore_limit_script.dart';
import '../social/instagram_media_viewer_script.dart';
import '../social/instagram_post_comments_script.dart';
import '../social/instagram_reels_hide_script.dart';
import '../social/instagram_reels_scroll_guard_script.dart';
import '../social/instagram_web_config.dart';
import 'safari_web_config.dart';
import '../youtube/google_auth_path_policy.dart';
import '../youtube/youtube_shorts_hide_script.dart';
import '../youtube/models/blocked_channel.dart';
import '../safety/content_safety_guard.dart';
import '../safety/youtube_restricted_mode_script.dart';
import '../youtube/block_keyword_policy.dart';
import '../youtube/blocked_url_guard.dart';
import '../youtube/youtube_channel_block_script.dart';
import '../youtube/youtube_playback_error_probe.dart';
import '../youtube/youtube_webview_factory.dart';
import '../youtube/youtube_url_redirect.dart';
import 'explorer_site.dart';
import 'google_search_keyword_block_script.dart';
import 'google_surface_url_block_script.dart';
import '../youtube/youtube_embed_surface_guard_script.dart';
import '../services/isle_app_log_service.dart';

/// WebView JS — 페이지 전환·차단 리다이렉트 중 evaluate 실패는 흔함 (크래시 아님)
Future<void> _runJsSafe(WebViewController controller, String js) async {
  final script = js.trim();
  if (script.isEmpty) return;
  try {
    await controller.runJavaScript(script);
  } on PlatformException catch (e) {
    if (e.code == 'FWFEvaluateJavaScriptError' ||
        e.message?.contains('JavaScript') == true) {
      IsleAppLogService.log(
        'WebView JS skipped (${e.code})',
        level: IsleLogLevel.debug,
      );
      return;
    }
    rethrow;
  } catch (e) {
    IsleAppLogService.log('WebView JS skipped: $e', level: IsleLogLevel.debug);
  }
}

const kSafariUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

const kAndroidUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

/// 인스타 WebView에 어떤 스크립트를 주입할지 — 실제 JS 실행(WebViewController)과
/// 분리한 순수 결정 결과. WebViewController 없이 유닛테스트하기 위해 뽑아냄
/// (2026-07-12, "DM 집중 모드가 죽은 설정이던 버그" 수정과 함께 도입).
class InstagramScriptPlan {
  const InstagramScriptPlan({
    required this.isAuthFlow,
    required this.minimalOnly,
    required this.runDmScrollPersistence,
    required this.runSaveThreadUrl,
    required this.runMediaViewerInstall,
    required this.runDmFocusScript,
    required this.runPostComments,
    required this.runReelsHide,
    required this.runReelsGuard,
    required this.runExploreGuard,
  });

  final bool isAuthFlow;
  final bool minimalOnly;
  final bool runDmScrollPersistence;
  final bool runSaveThreadUrl;
  final bool runMediaViewerInstall;
  final bool runDmFocusScript;
  final bool runPostComments;
  final bool runReelsHide;
  final bool runReelsGuard;
  final bool runExploreGuard;
}

/// 로그인/인증 흐름 경로면 아무 스크립트도 돌리지 않는다(기존 `keyboardFix`
/// 제외 — 그건 이 함수 호출 전에 항상 먼저 돈다). `instagramMinimalScripts`면
/// DM 스크롤 유지만(있으면) 돌리고 끝. 그 외엔 DM 모드/피드 모드로 완전히
/// 분리된 스크립트 집합을 돌린다 — 피드 전용 스크립트(릴스 숨김·탐색 가드 등)는
/// DM 모드에서 무슨 설정이든 절대 같이 켜지지 않는다.
InstagramScriptPlan planInstagramScripts({
  required String igPath,
  required bool instagramDmOnly,
  required bool instagramMinimalScripts,
  required bool dmFocusModeEnabled,
  required bool hideReels,
  required bool reelsGuardEnabled,
  required bool exploreGuardEnabled,
}) {
  if (InstagramAuthPathPolicy.isAuthFlowPath(igPath)) {
    return const InstagramScriptPlan(
      isAuthFlow: true,
      minimalOnly: false,
      runDmScrollPersistence: false,
      runSaveThreadUrl: false,
      runMediaViewerInstall: false,
      runDmFocusScript: false,
      runPostComments: false,
      runReelsHide: false,
      runReelsGuard: false,
      runExploreGuard: false,
    );
  }

  if (instagramMinimalScripts) {
    return InstagramScriptPlan(
      isAuthFlow: false,
      minimalOnly: true,
      runDmScrollPersistence: instagramDmOnly,
      runSaveThreadUrl: false,
      runMediaViewerInstall: false,
      runDmFocusScript: false,
      runPostComments: false,
      runReelsHide: false,
      runReelsGuard: false,
      runExploreGuard: false,
    );
  }

  return InstagramScriptPlan(
    isAuthFlow: false,
    minimalOnly: false,
    runDmScrollPersistence: true,
    runSaveThreadUrl: true,
    runMediaViewerInstall: true,
    runDmFocusScript: instagramDmOnly && dmFocusModeEnabled,
    runPostComments: !instagramDmOnly,
    runReelsHide: !instagramDmOnly && hideReels,
    runReelsGuard: !instagramDmOnly && reelsGuardEnabled,
    runExploreGuard: !instagramDmOnly &&
        igPath.startsWith('/explore') &&
        exploreGuardEnabled,
  );
}

/// WebView — iOS/Android 쿠키는 기본 저장(브런치 로그인 유지)
class IsleWebviewFactory {
  IsleWebviewFactory._();

  static String brunchLoginUrl() => 'https://brunch.co.kr/ko/login';

  static WebViewController create({
    required ExplorerSite site,
    required String initialUrl,
    required void Function(String url) onUrlChanged,
    required Future<void> Function() onPageReady,
    void Function(String url)? onPageStarted,
    void Function(int progress)? onLoadProgress,
    void Function(String message)? onYoutubeChannelProbe,
    void Function(String message)? onBrunchAuthorProbe,
    void Function(String message)? onPlaybackProbe,
    NavigationDecision Function(NavigationRequest request)? onNavigationRequest,
  }) {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F0F0F));

    if (site.isYoutube) {
      if (Platform.isIOS || Platform.isMacOS) {
        controller.setUserAgent(kYoutubeSafariUserAgent);
      } else if (Platform.isAndroid) {
        controller.setUserAgent(kYoutubeAndroidUserAgent);
      }
    } else if (site.isInstagram) {
      controller.setUserAgent(InstagramWebConfig.mobileSafariUserAgent);
    } else if (site == ExplorerSite.custom) {
      controller.setUserAgent(SafariWebConfig.mobileSafariUserAgent);
    } else if (Platform.isIOS || Platform.isMacOS) {
      controller.setUserAgent(kSafariUserAgent);
    } else if (Platform.isAndroid) {
      controller.setUserAgent(kAndroidUserAgent);
    }

    if (onYoutubeChannelProbe != null) {
      controller.addJavaScriptChannel(
        'IsleChannel',
        onMessageReceived: (m) => onYoutubeChannelProbe(m.message),
      );
    }
    if (onBrunchAuthorProbe != null) {
      controller.addJavaScriptChannel(
        'IsleBrunchAuthor',
        onMessageReceived: (m) => onBrunchAuthorProbe(m.message),
      );
    }
    if (onPlaybackProbe != null) {
      controller.addJavaScriptChannel(
        YoutubePlaybackErrorProbe.jsChannelName,
        onMessageReceived: (m) => onPlaybackProbe(m.message),
      );
    }

    if (site.isYoutube) {
      // YouTube: delegate는 [YoutubeSession.wireController]에서 재연결
    } else {
      controller.setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (c) {
            final url = c.url;
            if (url != null) onUrlChanged(url);
          },
          onPageStarted: onPageStarted,
          onProgress: onLoadProgress,
          onPageFinished: (_) => onPageReady(),
          onNavigationRequest: onNavigationRequest,
        ),
      );
    }

    final language = AppLocaleController.savedCodeOrDefault;
    final initialUri = WebLocalePolicy.initialUri(initialUrl, language);
    controller.loadRequest(initialUri,
        headers: WebLocalePolicy.headers(initialUri, language));
    return controller;
  }

  static Future<void> injectBlocks(
    WebViewController controller,
    ExplorerSite site, {
    List<BlockedChannel> youtubeChannels = const [],
    List<String> blockedVideoIds = const [],
    List<String> blockedKeywords = const [],
    List<String> blockedUrls = const [],
    List<String>? googleSurfaceBlockedUrls,
    List<BrunchBlockedAuthor> brunchAuthors = const [],
    bool instagramDmOnly = false,
    bool instagramMinimalScripts = false,
    bool youtubeBlockLightMode = false,
    String? pageUrl,
    bool youtubePlaybackBlocked = false,
  }) async {
    final effectiveSite = site == ExplorerSite.custom &&
            pageUrl != null &&
            YoutubeUrlRedirect.isYoutubeUrl(pageUrl)
        ? ExplorerSite.youtube
        : site;

    if (effectiveSite.isYoutube) {
      if (pageUrl != null && GoogleAuthPathPolicy.isAuthFlowUrl(pageUrl)) {
        return;
      }
      final hasAny = youtubeChannels.isNotEmpty ||
          blockedVideoIds.isNotEmpty ||
          blockedKeywords.isNotEmpty ||
          blockedUrls.isNotEmpty;
      if (hasAny) {
        await _runJsSafe(
          controller,
          YoutubeChannelBlockScript.build(
            youtubeChannels,
            blockedVideoIds: blockedVideoIds,
            blockedKeywords: blockedKeywords,
            blockedUrls: blockedUrls,
            lightMode: youtubeBlockLightMode,
          ),
        );
      }
      if (ContentSafetyGuard.enabled) {
        await _runJsSafe(controller, YoutubeRestrictedModeScript.install);
      }
      if (IsleUserDefaults.hideYoutubeShorts) {
        await _runJsSafe(controller, YoutubeShortsHideScript.install);
      }
      if (!hasAny && !IsleUserDefaults.hideYoutubeShorts) {
        await _teardown(controller);
      }
      return;
    }

    if (site.isBrunch || site == ExplorerSite.naver || site == ExplorerSite.blog) {
      final kws = [...blockedKeywords, ...IsleUserDefaults.brunchBlockKeywords];
      final hasAny = brunchAuthors.isNotEmpty || kws.isNotEmpty;
      if (!hasAny) return;
      await _runJsSafe(
        controller,
        BrunchContentBlockScript.build(authors: brunchAuthors, keywords: kws),
      );
      return;
    }

    if (site == ExplorerSite.custom && effectiveSite != ExplorerSite.youtube) {
      final embedUrls = blockedUrls.length > BlockedUrlGuard.maxGoogleSurfaceInjectUrls
          ? BlockedUrlGuard.googleSurfaceJsUrlsFromCanonical(blockedUrls)
          : blockedUrls;
      final surfaceUrls = googleSurfaceBlockedUrls ??
          BlockedUrlGuard.googleSurfaceJsUrlsFromCanonical(blockedUrls);
      await _runJsSafe(
        controller,
        YoutubeEmbedSurfaceGuardScript.build(
          channels: youtubeChannels,
          blockedVideoIds: blockedVideoIds,
          blockedKeywords: blockedKeywords,
          blockedUrls: embedUrls,
          playbackBlocked: youtubePlaybackBlocked,
          hideInlinePreview: IsleUserDefaults.blockGoogleYoutubeInlinePreview,
        ),
      );
      final adultAlwaysKws = ContentSafetyGuard.enabled
          ? ContentSafetyGuard.builtInAdultSearchKeywords
          : const <String>[];
      if (IsleUserDefaults.blockGoogleSearchKeywords &&
          (blockedKeywords.isNotEmpty || adultAlwaysKws.isNotEmpty)) {
        final searchQuery = pageUrl != null
            ? SafariWebConfig.searchQueryFromUrl(pageUrl)
            : null;
        final googleKeywords = BlockKeywordPolicy.forGoogleSearchInject(
          blockedKeywords,
          searchQuery: searchQuery,
        );
        // 사용자 키워드가 없어도 성인 내장 키워드만으로 주입 가능
        if (googleKeywords.isNotEmpty || adultAlwaysKws.isNotEmpty) {
          await _runJsSafe(
            controller,
            GoogleSearchKeywordBlockScript.build(
              googleKeywords,
              searchQuery: searchQuery,
              alwaysBlockKeywords: adultAlwaysKws,
            ),
          );
        }
      }
      if (IsleUserDefaults.blockGoogleSearchUrls) {
        // 검색 결과 "카드"는 특정 URL 블록리스트뿐 아니라, 스케줄 도메인·
        // 웹사이트 항상-차단 목록에 걸리는 사이트도 목록 자체에서 숨겨야 한다.
        // 지금까지는 클릭해서 들어갈 때만 막고 검색 결과 목록엔 그대로
        // 보이던 문제(2026-07-10 제보 "구글 검색에서 차단된 사이트가 그대로 나옴").
        final blockedDomains = <String>{
          ...ScheduleRuleEnforcement.mergedExpandedHostsNow(),
          ...WebsiteBlockStore.loadDomains(),
        }.toList();
        if (surfaceUrls.isNotEmpty || blockedDomains.isNotEmpty) {
          final js = GoogleSurfaceUrlBlockScript.build(
            surfaceUrls,
            blockedDomains: blockedDomains,
          );
          if (js.isNotEmpty) await _runJsSafe(controller, js);
        }
      }
      return;
    }

    if (site.isInstagram) {
      final igPath = Uri.tryParse(pageUrl ?? '')?.path ?? '';
      await _runJsSafe(controller, InstagramDmFocusScript.keyboardFix);
      // 어떤 스크립트를 돌릴지 결정하는 로직만 순수 함수로 뽑아뒀다
      // (planInstagramScripts) — WebViewController 없이도 유닛테스트 가능.
      final plan = planInstagramScripts(
        igPath: igPath,
        instagramDmOnly: instagramDmOnly,
        instagramMinimalScripts: instagramMinimalScripts,
        dmFocusModeEnabled: IsleUserDefaults.instagramDmFocusMode,
        hideReels: IsleUserDefaults.hideInstagramReels,
        reelsGuardEnabled: IsleUserDefaults.instagramReelsGuardEnabled,
        exploreGuardEnabled: IsleUserDefaults.instagramExploreGuardEnabled,
      );
      if (plan.isAuthFlow) return;
      if (plan.runDmScrollPersistence) {
        await _runJsSafe(controller, InstagramDmFocusScript.dmScrollPersistence);
      }
      if (plan.minimalOnly) return;
      if (plan.runSaveThreadUrl) {
        await _runJsSafe(controller, InstagramDmNavigationScript.saveThreadUrl);
      }
      if (plan.runMediaViewerInstall) {
        await _runJsSafe(controller, InstagramMediaViewerScript.install);
      }
      if (plan.runDmFocusScript) {
        await _runJsSafe(controller, InstagramDmFocusScript.script);
      }
      if (plan.runPostComments) {
        await _runJsSafe(controller, InstagramPostCommentsScript.install);
      }
      if (plan.runReelsHide) {
        await _runJsSafe(controller, InstagramReelsHideScript.install);
      }
      if (plan.runReelsGuard) {
        await _runJsSafe(
          controller,
          InstagramReelsScrollGuardScript.install(
            threshold: IsleUserDefaults.instagramReelsGuardThreshold,
          ),
        );
      }
      if (plan.runExploreGuard) {
        await _runJsSafe(
          controller,
          InstagramExploreLimitScript.install(
            threshold: IsleUserDefaults.instagramExploreGuardThreshold,
          ),
        );
      }
    }
  }

  static Future<void> _teardown(WebViewController controller) async {
    await _runJsSafe(
      controller,
      '''
      if (typeof window.__islePauseBlocks === 'function') window.__islePauseBlocks();
      if (window.__isleBlockObserver) window.__isleBlockObserver.disconnect();
      if (window.__isleBrunchObserver) window.__isleBrunchObserver.disconnect();
    ''',
    );
  }
}
