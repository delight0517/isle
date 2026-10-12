import 'dart:io' show Platform;

import 'isle_apple_platform.dart';

/// UI·라우트 **노출 여부** — OS별 기능이 섞이지 않게 하는 게이트.
///
/// - 문구 분기 → [PlatformBlockCopy] / [PlatformCopyResolver]
/// - 차단 동작 → [BlockingController] (android-parity 규칙)
/// - 화면·타일 on/off → **여기**
abstract final class PlatformFeatureGate {
  PlatformFeatureGate._();

  static bool get isAndroid => Platform.isAndroid;
  static bool get isIos => Platform.isIOS;
  static bool get isMac => Platform.isMacOS;

  /// iOS·Android 모두 기본 브라우저 설정 안내 (문구는 플랫폼별).
  static bool get defaultBrowserOnboarding => isIos || isAndroid;

  /// Apple 기본 브라우저 entitlement·배포 가이드 — iOS만.
  static bool get appleDefaultBrowserEntitlementGuide => isIos;

  /// Safari Content Blocker 확장 — iOS만.
  static bool get safariContentBlockerExtension => isIos;

  /// FamilyControls / Screen Time 앱 피커.
  static bool get screenTimeAppPicker => IsleApplePlatform.isScreenTimeHost;

  /// Android 접근성·VPN 차단 설정 화면.
  static bool get androidNativeBlockSettings => isAndroid;

  /// 차단 기능 투명성 화면 (`/settings/iphone-blocking` — Android도 별도 카피).
  static bool get blockingCapabilitiesScreen => isIos || isAndroid;

  /// iOS 앱 삭제 방지 안내 (Screen Time).
  static bool get appDeletionGuardGuide => isIos;

  /// RuleRemovalLock·스케줄 등 공통 Isle 로직.
  static bool get sharedIsleBlockLogic => true;
}
