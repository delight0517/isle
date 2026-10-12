import 'package:package_info_plus/package_info_plus.dart';

/// 앱 이름·버전 단일 출처 — pubspec `version:` 과 반드시 동기화.
/// 업데이트 시 이 파일 + pubspec.yaml 둘 다 올릴 것.
class AppReleaseInfo {
  AppReleaseInfo._();

  static const appName = '모아';
  static String version = '1.6.0';
  static String buildNumber = '380';

  /// Read the installed bundle; CLI build-number overrides must not show stale metadata.
  static Future<void> initialize() async {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isNotEmpty) version = info.version;
    if (info.buildNumber.isNotEmpty) buildNumber = info.buildNumber;
  }

  /// 스크린샷·에이전트 응답·로그에 쓰는 공식 라벨
  static String get label => '$appName v$version+$buildNumber';

  static String get lightLabel => '$appName Light v$version+$buildNumber';

  static String get pubspecVersion => '$version+$buildNumber';

  static const rebuildProjectRelative = 'isle';

  /// Run from the Isle repository root.
  static String get rebuildCommand => './tool/agent_build_dispatch.sh auto';

  /// macOS 핫리로드 전용 (실기기 설치는 agent_build_dispatch 사용)
  static String get devHotReloadCommand => 'flutter pub get && flutter run';

  static String logPrefix(DateTime at) =>
      '[${at.toUtc().toIso8601String()}] [$label]';
}
