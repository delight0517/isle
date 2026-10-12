import 'dart:io' show Platform;

import '../social/instagram_safari_launch_guard.dart';
import 'platform_block_intent.dart';

/// Google·Instagram 패스키(WebAuthn) — WKWebView/Android WebView 한계
class PasskeyLoginService {
  PasskeyLoginService._();

  /// iOS WKWebView는 Apple 브라우저 entitlement 없이 패스키 불가
  static bool get webViewPasskeysBroken => Platform.isIOS || Platform.isAndroid;

  static bool isGoogleSignInUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('accounts.google.com') ||
        u.contains('google.com/signin') ||
        u.contains('servicelogin');
  }

  static bool isInstagramSignInUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('instagram.com') &&
        (u.contains('/accounts/login') || u.contains('/challenge/'));
  }

  /// 패스키 챌린지 URL — WebView에서 열면 실패하는 경우가 많음
  static bool isPasskeyChallengeUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('accounts.google.com') &&
        (u.contains('/challenge/pk') ||
            u.contains('passkey') ||
            u.contains('webauthn'))) {
      return true;
    }
    return false;
  }

  static bool shouldProbePasskeyOnPage(String url) =>
      isGoogleSignInUrl(url) || isInstagramSignInUrl(url);

  static bool shouldInterceptInWebView(String url) =>
      webViewPasskeysBroken && isPasskeyChallengeUrl(url);

  /// YouTube — Safari 패스키는 차단 우회가 되므로 금지. Instagram만 조건부 허용.
  static bool canOfferSafariPasskey({required bool youtube}) {
    if (youtube) return false;
    return !InstagramSafariLaunchGuard.isEscapeBlocked;
  }

  static String passkeyDeniedMessage({required bool youtube}) {
    final browser = PlatformBlockCopy.externalPasskeyBrowserName;
    if (youtube) {
      return '패스키는 $browser를 열어 YouTube 차단이 풀릴 수 있어요 · 비밀번호로 웹뷰 로그인하세요';
    }
    return '차단·한도 중에는 $browser 패스키를 쓸 수 없어요 · 비밀번호로 로그인하세요';
  }
}
