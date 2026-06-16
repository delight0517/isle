import 'dart:io' show Platform;

/// iOS + macOS — Screen Time · FamilyControls · DeviceActivity 공통
class IsleApplePlatform {
  IsleApplePlatform._();

  static bool get isScreenTimeHost => Platform.isIOS || Platform.isMacOS;

  /// iOS Screen Time · macOS · Android 접근성/VPN — 네이티브 앱·웹 차단 UI 노출
  static bool get isNativeBlockHost =>
      Platform.isIOS || Platform.isMacOS || Platform.isAndroid;

  static String get screenTimeSettingsLabel =>
      Platform.isMacOS ? 'macOS Screen Time' : 'iOS Screen Time';

  static String get externalBrowserLabel =>
      Platform.isMacOS ? 'Safari·Chrome' : 'Safari';

  static String get osBlockDetailRoute => Platform.isAndroid
      ? '/settings/android-system-block'
      : '/settings/safari-youtube-os';
}
