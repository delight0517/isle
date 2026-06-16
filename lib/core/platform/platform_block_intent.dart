import 'dart:io' show Platform;

import 'isle_apple_platform.dart';

/// Droid Architect — OS 훅이 아닌 **사용자 의도** 단위 라벨
enum PlatformBlockIntent {
  /// 앱 밖 브라우저·시스템 앱에서 유튜브 접근 줄이기
  blockExternalYoutube,

  /// Isle WebView 안에서만 시청·한도·스케줄
  inAppYoutubeShell,
}

/// 플랫폼별 UI·설정 경로
class PlatformBlockCopy {
  PlatformBlockCopy._();

  static bool get isAndroid => Platform.isAndroid;
  static bool get isIos => Platform.isIOS;
  static bool get isMac => Platform.isMacOS;
  static bool get isAppleScreenTime => IsleApplePlatform.isScreenTimeHost;

  static String get externalBrowserName {
    if (isAndroid) return 'Chrome 등';
    if (isMac) return 'Safari·Chrome';
    return 'Safari';
  }

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
}
