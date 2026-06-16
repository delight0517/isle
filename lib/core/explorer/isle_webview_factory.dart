import 'dart:io' show Platform;

import 'package:flutter/material.dart' show Color;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../brunch/brunch_blocked_author_store.dart';
import '../brunch/brunch_content_block_script.dart';
import '../services/isle_user_defaults.dart';
import '../social/instagram_dm_focus_script.dart';
import '../social/instagram_dm_navigation_script.dart';
import '../social/instagram_media_viewer_script.dart';
import '../social/instagram_post_comments_script.dart';
import '../social/instagram_reels_hide_script.dart';
import '../social/instagram_reels_scroll_guard_script.dart';
import '../social/instagram_web_config.dart';
import 'safari_web_config.dart';
import '../youtube/youtube_shorts_hide_script.dart';
import '../youtube/models/blocked_channel.dart';
import '../safety/content_safety_guard.dart';
import '../safety/youtube_restricted_mode_script.dart';
import '../youtube/youtube_channel_block_script.dart';
import '../youtube/youtube_playback_error_probe.dart';
import '../youtube/youtube_webview_factory.dart';
import '../youtube/youtube_url_redirect.dart';
import 'explorer_site.dart';
import 'google_search_keyword_block_script.dart';
import 'google_surface_url_block_script.dart';
import '../youtube/youtube_embed_surface_guard_script.dart';

const kSafariUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

const kAndroidUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

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
        ),
      );
    }

    controller.loadRequest(Uri.parse(initialUrl));
    return controller;
  }

  static Future<void> injectBlocks(
    WebViewController controller,
    ExplorerSite site, {
    List<BlockedChannel> youtubeChannels = const [],
    List<String> blockedVideoIds = const [],
    List<String> blockedKeywords = const [],
    List<String> blockedUrls = const [],
    List<BrunchBlockedAuthor> brunchAuthors = const [],
    bool instagramDmOnly = false,
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
      final hasAny = youtubeChannels.isNotEmpty ||
          blockedVideoIds.isNotEmpty ||
          blockedKeywords.isNotEmpty ||
          blockedUrls.isNotEmpty;
      if (hasAny) {
        await controller.runJavaScript(
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
        await controller.runJavaScript(YoutubeRestrictedModeScript.install);
      }
      if (IsleUserDefaults.hideYoutubeShorts) {
        await controller.runJavaScript(YoutubeShortsHideScript.install);
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
      await controller.runJavaScript(
        BrunchContentBlockScript.build(authors: brunchAuthors, keywords: kws),
      );
      return;
    }

    if (site == ExplorerSite.custom && effectiveSite != ExplorerSite.youtube) {
      await controller.runJavaScript(
        YoutubeEmbedSurfaceGuardScript.build(
          channels: youtubeChannels,
          blockedVideoIds: blockedVideoIds,
          blockedKeywords: blockedKeywords,
          blockedUrls: blockedUrls,
          playbackBlocked: youtubePlaybackBlocked,
          hideInlinePreview: IsleUserDefaults.blockGoogleYoutubeInlinePreview,
        ),
      );
      if (IsleUserDefaults.blockGoogleSearchKeywords && blockedKeywords.isNotEmpty) {
        await controller.runJavaScript(GoogleSearchKeywordBlockScript.build(blockedKeywords));
      }
      if (IsleUserDefaults.blockGoogleSearchUrls && blockedUrls.isNotEmpty) {
        final js = GoogleSurfaceUrlBlockScript.build(blockedUrls);
        if (js.isNotEmpty) await controller.runJavaScript(js);
      }
      return;
    }

    if (site.isInstagram) {
      // 키보드 뷰포트 픽스 — DM 입력창이 키보드에 가리는 현상 완화
      await controller.runJavaScript(InstagramDmFocusScript.keyboardFix);
      await controller.runJavaScript(InstagramDmFocusScript.dmScrollPersistence);
      await controller.runJavaScript(InstagramDmNavigationScript.saveThreadUrl);
      await controller.runJavaScript(InstagramMediaViewerScript.install);
      if (instagramDmOnly) {
        await controller.runJavaScript(InstagramDmFocusScript.script);
        // DM 스레드 내 릴스·SPA — 댓글 강제 주입은 뷰어·뒤로가기와 충돌 (§2026-06-08)
      } else {
        // 일반 피드 모드: 포스트(/p/ /reel/) 진입 시에도 댓글 영역 표시
        await controller.runJavaScript(InstagramPostCommentsScript.install);
        if (IsleUserDefaults.hideInstagramReels) {
          await controller.runJavaScript(InstagramReelsHideScript.install);
        }
        if (IsleUserDefaults.instagramReelsGuardEnabled) {
          await controller.runJavaScript(
            InstagramReelsScrollGuardScript.install(
              threshold: IsleUserDefaults.instagramReelsGuardThreshold,
            ),
          );
        }
      }
    }
  }

  static Future<void> _teardown(WebViewController controller) async {
    await controller.runJavaScript('''
      if (typeof window.__islePauseBlocks === 'function') window.__islePauseBlocks();
      if (window.__isleBlockObserver) window.__isleBlockObserver.disconnect();
      if (window.__isleBrunchObserver) window.__isleBrunchObserver.disconnect();
    ''');
  }
}
