/// `main_light.dart` 에서 true — Android Lite 빌드
class AppBuildConfig {
  AppBuildConfig._();

  static bool isLightBuild = false;

  /// `main_youtube_focus.dart` — 검색·요약·재생만
  static bool isYoutubeFocusBuild = false;

  static bool get enableFeed => !isLightBuild;
  static bool get enableIsland => !isLightBuild;
  static bool get enableExplore => !isLightBuild;
  static bool get enableAiFeatures => !isLightBuild;
  static bool get enableGenreBlockAi => !isLightBuild;
  static bool get enableInterestPipeline => !isLightBuild;
  static bool get enablePersonalLibraryDigest => !isLightBuild;

  /// Play 초기 출시 — UGC·소셜 피드 비노출 (심사 후 true 검토).
  static bool get enableSocialUgc => false;

  static String get appTitle {
    if (isYoutubeFocusBuild) return 'Isle Focus';
    if (isLightBuild) return 'Isle Light';
    return 'Isle';
  }
}
