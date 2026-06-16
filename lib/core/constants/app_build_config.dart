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

  static String get appTitle {
    if (isYoutubeFocusBuild) return 'Isle Focus';
    if (isLightBuild) return 'Isle Light';
    return 'Isle';
  }
}
