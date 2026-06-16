/// 앱 이름·버전 단일 출처 — pubspec `version:` 과 반드시 동기화.
/// 업데이트 시 이 파일 + pubspec.yaml 둘 다 올릴 것.
class AppReleaseInfo {
  AppReleaseInfo._();

  static const appName = 'Isle';
  static const version = '1.6.0';
  static const buildNumber = '205';

  /// 스크린샷·에이전트 응답·로그에 쓰는 공식 라벨
  static String get label => '$appName v$version+$buildNumber';

  static String get lightLabel => '$appName Light v$version+$buildNumber';

  static String get pubspecVersion => '$version+$buildNumber';

  static const rebuildProjectRelative = 'isle';
  static const rebuildProjectAbsolute =
      '/Users/rogan/Desktop/appDev/library-content-sns/11-1Isle/isle';

  static String get rebuildCommand =>
      'cd "$rebuildProjectAbsolute" && flutter pub get && flutter run';

  static String logPrefix(DateTime at) =>
      '[${at.toUtc().toIso8601String()}] [$label]';
}
