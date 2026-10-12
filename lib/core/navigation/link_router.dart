import 'package:url_launcher/url_launcher.dart';

import '../safety/content_safety_guard.dart';
import 'share_link_router.dart';

/// QR·수동 입력 URL → Safe Browser(인앱 WebView) 라우트
class LinkRouter {
  LinkRouter._();

  /// 카카오페이·토스 등 — QR에 https가 들어와도 네이티브 앱 핸드오프가 우선인 호스트
  static const _nativeAppHostSuffixes = [
    'kakaopay.com',
    'pay.kakao.com',
    'kko.to',
    'kakao.com',
    'supertoss.im',
    'toss.im',
    'toss.me',
    'naver.me',
    'naverpay.com',
    'pay.naver.com',
    'shinhancard.com',
    'kbstar.com',
    'wooricard.com',
    'samsungcard.com',
    'lottecard.co.kr',
    'hyundaicard.com',
    'bccard.com',
    'bankpay.or.kr',
    'lpayapp.com',
    'ssgpay.com',
    'smilepay.co.kr',
  ];

  static String? normalizeHttpUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null || uri.host.isEmpty) return null;
      return trimmed;
    }

    final candidate = 'https://$trimmed';
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) return null;
    if (!uri.host.contains('.')) return null;
    return candidate;
  }

  static bool isHttpUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  /// QR·URL 입력 → 필터·차단이 적용된 인앱 브라우저 경로
  static String? safeBrowserRoute(String raw) {
    final url = normalizeHttpUrl(raw);
    if (url == null) return null;
    if (ContentSafetyGuard.matchUrl(url) != null) return null;
    final sanitized = ContentSafetyGuard.sanitizeUrl(url);
    return ShareLinkRouter.inAppRouteForUrl(sanitized, preferBrowser: true);
  }

  /// `kakaopay://` · `intent://` 등 http(s)가 아닌 앱 딥링크
  static bool isNonHttpAppLink(String raw) {
    final uri = resolveAppLaunchUri(raw);
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    return scheme.isNotEmpty && scheme != 'http' && scheme != 'https';
  }

  /// 유니버설 링크(https)지만 결제·메신저 앱으로 열어야 하는 QR
  static bool prefersNativeAppLaunch(String raw) {
    final url = normalizeHttpUrl(raw);
    if (url == null) return false;
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    return _nativeAppHostSuffixes.any(
      (suffix) => host == suffix || host.endsWith('.$suffix'),
    );
  }

  /// QR 원문 → [launchNativeApp]에 넘길 URI (Android intent 파싱 포함)
  static Uri? resolveAppLaunchUri(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('intent://')) {
      final schemeUri = _intentSchemeUri(trimmed);
      if (schemeUri != null) return schemeUri;
      final fallback = _intentBrowserFallback(trimmed);
      if (fallback != null) return Uri.tryParse(fallback);
      return Uri.tryParse(trimmed);
    }

    return Uri.tryParse(trimmed);
  }

  static String? _intentBrowserFallback(String intentUrl) {
    final match = RegExp(r'S\.browser_fallback_url=([^;]+)', caseSensitive: false)
        .firstMatch(intentUrl);
    if (match == null) return null;
    return Uri.decodeComponent(match.group(1)!);
  }

  static Uri? _intentSchemeUri(String intentUrl) {
    final schemeMatch =
        RegExp(r'scheme=([^;]+)', caseSensitive: false).firstMatch(intentUrl);
    if (schemeMatch == null) return null;
    final scheme = schemeMatch.group(1)!.trim();
    if (scheme.isEmpty) return null;

    final withoutIntent = intentUrl.split('#Intent').first;
    final path = withoutIntent.startsWith('intent://')
        ? withoutIntent.substring('intent://'.length)
        : withoutIntent;
    return Uri.tryParse('$scheme://$path');
  }

  /// OS에 설치된 앱으로 넘기기 — WebView보다 유니버설 링크·커스텀 스킴에 적합
  static Future<bool> launchNativeApp(Uri uri) async {
    for (final mode in [
      LaunchMode.externalNonBrowserApplication,
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]) {
      try {
        if (await launchUrl(uri, mode: mode)) return true;
      } on Object {
        // 다음 LaunchMode 시도
      }
    }
    return false;
  }
}
