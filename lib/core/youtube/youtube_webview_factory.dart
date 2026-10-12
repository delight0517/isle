import 'dart:io' show Platform;

import 'package:flutter/material.dart' show Color;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../safety/content_safety_guard.dart';
import '../safety/youtube_restricted_mode_script.dart';
import '../services/isle_user_defaults.dart';
import '../localization/locale_controller.dart';
import '../localization/web_locale_policy.dart';
import 'models/blocked_channel.dart';
import 'youtube_channel_block_script.dart';
import 'youtube_shorts_hide_script.dart';
import 'youtube_open_app_hide_script.dart';

/// Safari 유사 UA — Google 로그인 차단 완화.
/// 접미 `kIsleYoutubeWebShellUaToken`은 Isle WebView 식별용(서버/로그); OS Screen Time 예외는 불가.
const kYoutubeSafariUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

const kIsleYoutubeWebShellUaToken = ' IsleYouTubeShell/1';

const kYoutubeAndroidUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

/// iOS/macOS WKWebView + Android WebView — 유튜브 커스텀 쉘용 컨트롤러
class YoutubeWebviewFactory {
  YoutubeWebviewFactory._();

  static String homeUrl() {
    if (Platform.isIOS || Platform.isAndroid) return 'https://m.youtube.com';
    return IsleUserDefaults.youtubeUseDesktopSite
        ? 'https://www.youtube.com'
        : 'https://m.youtube.com';
  }

  static String signInUrl() {
    final continueUrl = (Platform.isIOS || Platform.isAndroid)
        ? 'https://m.youtube.com/'
        : (IsleUserDefaults.youtubeUseDesktopSite
            ? 'https://www.youtube.com/'
            : 'https://m.youtube.com/');
    return 'https://accounts.google.com/ServiceLogin?service=youtube&continue=$continueUrl';
  }

  static WebViewController create({
    required void Function(String url) onUrlChanged,
    required Future<void> Function() onPageReady,
    void Function(String message)? onChannelProbe,
    String? initialUrl,
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

    if (Platform.isIOS || Platform.isMacOS) {
      // 순수 Safari UA 사용 — 구글 봇 감지 완화 (로그아웃 빈도 감소)
      controller.setUserAgent(kYoutubeSafariUserAgent);
    } else if (Platform.isAndroid) {
      controller.setUserAgent(kYoutubeAndroidUserAgent);
    }

    if (onChannelProbe != null) {
      controller.addJavaScriptChannel(
        'IsleChannel',
        onMessageReceived: (msg) => onChannelProbe(msg.message),
      );
    }

    controller.setNavigationDelegate(
      NavigationDelegate(
        onUrlChange: (c) {
          final url = c.url;
          if (url != null) onUrlChanged(url);
        },
        onPageFinished: (_) => onPageReady(),
      ),
    );

    final language = AppLocaleController.savedCodeOrDefault;
    final initialUri = WebLocalePolicy.initialUri(initialUrl ?? homeUrl(), language);
    controller.loadRequest(initialUri,
        headers: WebLocalePolicy.headers(initialUri, language));
    return controller;
  }

  static Future<void> injectBlockScript(
    WebViewController controller,
    List<BlockedChannel> blocked, {
    List<String> blockedVideoIds = const [],
    List<String> blockedKeywords = const [],
    bool lightMode = false,
  }) async {
    final hasAny = blocked.isNotEmpty || blockedVideoIds.isNotEmpty || blockedKeywords.isNotEmpty;
    if (!hasAny) {
      await teardownBlockScript(controller);
      if (IsleUserDefaults.hideYoutubeShorts) {
        await controller.runJavaScript(YoutubeShortsHideScript.install);
      }
      return;
    }
    await controller.runJavaScript(
      YoutubeChannelBlockScript.build(
        blocked,
        blockedVideoIds: blockedVideoIds,
        blockedKeywords: blockedKeywords,
        lightMode: lightMode,
      ),
    );
    if (ContentSafetyGuard.enabled) {
      await controller.runJavaScript(YoutubeRestrictedModeScript.install);
    }
    if (IsleUserDefaults.hideYoutubeShorts) {
      await controller.runJavaScript(YoutubeShortsHideScript.install);
    }
  }

  static Future<void> injectShortsHide(WebViewController controller) async {
    if (!IsleUserDefaults.hideYoutubeShorts) return;
    await controller.runJavaScript(YoutubeShortsHideScript.install);
  }

  /// m.youtube 「Open App」 상단 버튼 숨김 (좋아요·구독 등은 유지)
  static Future<void> hideOpenAppPrompt(WebViewController controller) async {
    await controller.runJavaScript(YoutubeOpenAppHideScript.install);
  }

  static Future<void> teardownBlockScript(WebViewController controller) async {
    await controller.runJavaScript('''
      if (typeof window.__islePauseBlocks === 'function') window.__islePauseBlocks();
      if (window.__isleBlockObserver) window.__isleBlockObserver.disconnect();
      if (window.__isleBlockInterval) { clearInterval(window.__isleBlockInterval); window.__isleBlockInterval = null; }
    ''');
  }
}
