import 'dart:io' show Platform;

/// 런타임 OS 종류 — [PlatformCopyResolver]·테스트 공통.
enum PlatformKind {
  ios,
  android,
  macOS,
}

/// `dart:io` Platform → [PlatformKind] (UI·copy 분기 단일 진입).
abstract final class PlatformKindDetect {
  PlatformKindDetect._();

  static PlatformKind get current {
    if (Platform.isAndroid) return PlatformKind.android;
    if (Platform.isMacOS) return PlatformKind.macOS;
    return PlatformKind.ios;
  }
}
