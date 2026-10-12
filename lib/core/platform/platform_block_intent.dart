import 'dart:io' show Platform;

import 'isle_apple_platform.dart';
import 'platform_copy_resolver.dart';
import 'platform_kind.dart';

/// Droid Architect — OS 훅이 아닌 **사용자 의도** 단위 라벨
enum PlatformBlockIntent {
  /// 앱 밖 브라우저·시스템 앱에서 유튜브 접근 줄이기
  blockExternalYoutube,

  /// Isle WebView 안에서만 시청·한도·스케줄
  inAppYoutubeShell,
}

/// 플랫폼별 UI·설정 경로 — **런타임 단일 출처**.
///
/// ### Parity contract (iOS ↔ Android)
/// 1. OS 전용 용어(Safari, Screen Time, Chrome, 접근성…)는 위젯에 하드코딩하지 말고
///    [PlatformCopyResolver]에 분기 → 여기서 [PlatformKindDetect.current]로 위임.
/// 2. 양쪽을 "웹 브라우저" 같은 중립 문구로 **통일하지 말 것** — iOS는 Safari 유지.
/// 3. 기능 노출/숨김은 [PlatformFeatureGate], 차단 동작은 [BlockingController].
/// 4. 회귀 방지: `test/core/platform/platform_copy_parity_test.dart` +
///    `dart run tool/check_platform_ui_strings.dart`
class PlatformBlockCopy {
  PlatformBlockCopy._();

  static PlatformKind get _k => PlatformKindDetect.current;

  static bool get isAndroid => Platform.isAndroid;
  static bool get isIos => Platform.isIOS;
  static bool get isMac => Platform.isMacOS;
  static bool get isAppleScreenTime => IsleApplePlatform.isScreenTimeHost;

  static String get externalBrowserName => PlatformCopyResolver.externalBrowserName(_k);

  static String get systemSettingsName {
    if (isAndroid) return '디지털 웰빙 · 앱 타이머';
    if (isMac) return 'macOS Screen Time';
    return 'Screen Time';
  }

  static String get settingsTileTitle => '브라우저 유튜브 → Isle 트래킹';

  static String get settingsTileSubtitle {
    if (isAndroid) {
      return 'Chrome 차단 · Isle WebView에서 시청·시간 기록';
    }
    if (isMac) {
      return 'Safari·Chrome 차단 · Isle에서만 시청·한도';
    }
    return 'Safari 차단 · Isle에서만 시청·한도';
  }

  static String get settingsRoute => '/settings/browser-youtube-tracking';

  static String get osBlockDetailRoute => IsleApplePlatform.osBlockDetailRoute;

  static String get scheduleSyncHint {
    if (isAndroid) {
      return 'WebView·앱 내 잠금은 Isle가 처리 · Chrome/YouTube 앱은 시스템 설정';
    }
    if (isMac) {
      return 'WebView·Screen Time·앱 종료 동기화 중';
    }
    return 'WebView·Screen Time 동기화 중';
  }

  static String get focusPanelExternalHint {
    if (isAndroid) {
      return 'Chrome·YouTube 앱은 「디지털 웰빙」 또는 DNS 필터에서 차단하세요.';
    }
    if (isMac) {
      return 'Safari·Chrome·YouTube 앱은 Screen Time 또는 Isle Mac 차단으로 줄이세요.';
    }
    return 'Safari·다른 앱의 YouTube는 iOS 설정 → Screen Time에서 직접 허용/차단하세요.';
  }

  static String get inAppBrowserLabel => PlatformCopyResolver.inAppBrowserLabel(_k);

  static String get inAppBrowserNavLabel => PlatformCopyResolver.inAppBrowserNavLabel(_k);

  static String get safeBrowserIntro => PlatformCopyResolver.safeBrowserIntro(_k);

  static String get qrScannerHint => PlatformCopyResolver.qrScannerHint(_k);

  static String get qrOpenSubtitle => PlatformCopyResolver.qrOpenSubtitle(_k);

  static String get shareFromExternalAppTitle =>
      PlatformCopyResolver.shareFromExternalAppTitle(_k);

  static String get googleSearchFilterLabel =>
      PlatformCopyResolver.googleSearchFilterLabel(_k);

  static String googleSearchHideSnack(String terms) =>
      '「$terms」 포함 검색 결과를 ${googleSearchFilterLabel}에서 숨겨요';

  static String get urlSheetTitle => PlatformCopyResolver.urlSheetTitle(_k);

  static String get urlSheetSubtitle => PlatformCopyResolver.urlSheetSubtitle(_k);

  static String get urlSheetOpenButton => PlatformCopyResolver.urlSheetOpenButton(_k);

  static String get externalPasskeyBrowserName =>
      PlatformCopyResolver.externalPasskeyBrowserName(_k);

  static String get defaultBrowserTileSubtitle =>
      PlatformCopyResolver.defaultBrowserTileSubtitle(_k);

  static String get defaultBrowserSettingsSteps {
    if (isAndroid) {
      return '설정 → 앱 → 기본 앱 → 브라우저 앱 → Isle';
    }
    return '설정 → 앱 → 기본 앱 → 브라우저 → Isle';
  }

  static String get externalAppsSubtitle => PlatformCopyResolver.externalAppsSubtitle(_k);

  static String get blockingCapabilitiesTitle =>
      PlatformCopyResolver.blockingCapabilitiesTitle(_k);

  static String get blockFocusExternalAppsHint =>
      PlatformCopyResolver.blockFocusExternalAppsHint(_k);

  static String get systemYoutubeBlockGuideLabel =>
      PlatformCopyResolver.systemYoutubeBlockGuideLabel(_k);

  static String passkeyLoginSnackMessage() =>
      '${externalPasskeyBrowserName}에서 패스키로 로그인 후 이 화면으로 돌아오세요';

  static String passkeyLoginDialogMessage() =>
      '${externalPasskeyBrowserName}에서 패스키로 로그인하면 Isle WebView로 세션을 가져올게요.';

  static String passkeyLoginButtonLabel() => '${externalPasskeyBrowserName}로';

  static String externalBrowserLoginSnack() =>
      '${externalPasskeyBrowserName}에서 로그인 후 「DM 열기」를 눌러 주세요';

  static String externalBrowserLoginBlockedSnack() =>
      '차단·한도 중에는 $externalPasskeyBrowserName 로그인을 쓸 수 없어요';

  static String externalBrowserLoginButtonLabel() =>
      '$externalPasskeyBrowserName로 로그인 (권장)';

  static String get inAppBrowserMenuHint => PlatformCopyResolver.inAppBrowserMenuHint(_k);

  static String get keywordFilterScopeHint =>
      '제목·채널명에 키워드가 들어간 영상·글을 피드·유튜브 검색에서 숨깁니다. '
      '특정 영상 1개만 막으려면 「링크로 숨기기」를 쓰세요.\n'
      '적용: Isle 피드 + YouTube 검색·피드 + $googleSearchFilterLabel·Discover.\n'
      '$inAppBrowserMenuHint';

  static String get blockedUrlMenuHint => PlatformCopyResolver.blockedUrlMenuHint(_k);

  static String get blockedUrlScopeHint =>
      'YouTube 검색·피드·구글 검색·Discover에서 해당 링크 카드를 숨깁니다.\n'
      '$blockedUrlMenuHint';

  static String get scheduleWebTargetChipLabel =>
      PlatformCopyResolver.scheduleWebTargetChipLabel(_k);

  static String get nativeInstalledAppLabel =>
      PlatformCopyResolver.nativeInstalledAppLabel(_k);

  static String get nativeInstalledAppPickHint =>
      PlatformCopyResolver.nativeInstalledAppPickHint(_k);

  static String get appShieldPauseTitle =>
      PlatformCopyResolver.appShieldPauseTitle(_k);

  static String get appShieldPauseSubtitle =>
      PlatformCopyResolver.appShieldPauseSubtitle(_k);

  static String get appShieldPausedBannerTitle =>
      PlatformCopyResolver.appShieldPausedBannerTitle(_k);

  static String get morningBlockQuickNote =>
      PlatformCopyResolver.morningBlockQuickNote(_k);

  static String get isleInAppUsageFootnote =>
      PlatformCopyResolver.isleInAppUsageFootnote(_k);

  static String get kakaoWebBlockButtonLabel =>
      PlatformCopyResolver.kakaoWebBlockButtonLabel(_k);
}
