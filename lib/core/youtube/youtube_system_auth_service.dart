import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/env.dart';
import '../library/youtube_library_service.dart';
import '../services/isle_external_launch_guard.dart';
import 'youtube_safari_launch_guard.dart';
import 'youtube_webview_factory.dart';

class YoutubeSystemAuthResult {
  final bool success;
  final String message;

  const YoutubeSystemAuthResult(this.success, {required this.message});
}

/// WebView 로그인 실패 시 — google_sign_in(ASWebAuthenticationSession) · 인앱 Safari
class YoutubeSystemAuthService {
  YoutubeSystemAuthService._();

  /// YouTube Data API용 Google 로그인 (iOS: 시스템 인증 세션)
  static Future<YoutubeSystemAuthResult> signInForYoutubeApi() async {
    if (!Env.isGoogleSignInConfigured) {
      return YoutubeSystemAuthResult(
        false,
        message: YoutubeLibraryService.setupHint,
      );
    }
    final result = await YoutubeLibraryService.signIn();
    if (result.success) {
      final email = result.email ?? YoutubeLibraryService.currentAccount?.email ?? '';
      return YoutubeSystemAuthResult(
        true,
        message: email.isNotEmpty
            ? '$email 로그인됨 — 나중에 볼·구독·유형 차단 검색 가능'
            : '로그인됨 — 나중에 볼·구독 가져오기 가능',
      );
    }
    return YoutubeSystemAuthResult(
      false,
      message: result.message ?? '로그인이 취소되었어요.',
    );
  }

  /// Google 계정 페이지 — 인앱 Safari (차단 중이면 열지 않음 · youtube 우회 방지)
  static Future<bool> openGoogleLoginInAppBrowser({BuildContext? context}) async {
    final deny = YoutubeSafariLaunchGuard.denyBrowsingEscape();
    if (deny != null) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$deny · Safari 로그인은 사용할 수 없어요')),
        );
      }
      return false;
    }
    return IsleExternalLaunchGuard.launchAllowed(
      YoutubeWebviewFactory.signInUrl(),
      mode: LaunchMode.inAppBrowserView,
      context: context,
    );
  }

  static String get webViewLoginHint => Platform.isIOS
      ? 'WebView에서 「로그인할 수 없음」이면 아래 「시스템 로그인」을 쓰세요.'
      : '로그인이 막히면 시스템 로그인 또는 Chrome을 사용하세요.';
}
