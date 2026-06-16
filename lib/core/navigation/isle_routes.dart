import '../constants/app_build_config.dart';

/// Light / Full 경로 분기
class IsleRoutes {
  IsleRoutes._();

  static String get blockSchedules => AppBuildConfig.isLightBuild
      ? '/light/schedules'
      : AppBuildConfig.isYoutubeFocusBuild
          ? '/youtube-focus/more/schedules'
          : '/settings/block-schedules';

  static String blockScheduleEdit(String id) => AppBuildConfig.isLightBuild
      ? '/light/schedules/$id'
      : AppBuildConfig.isYoutubeFocusBuild
          ? '/youtube-focus/more/schedules/$id'
          : '/settings/block-schedules/$id';

  /// WebView·오버레이 등 셸 밖에서도 안전 — `/settings/youtube-limits`는 셸 분기 안이라 흰 화면
  static String get youtubeLimits => AppBuildConfig.isLightBuild
      ? '/light/youtube-limits'
      : AppBuildConfig.isYoutubeFocusBuild
          ? '/youtube-focus/more/youtube-limits'
          : '/youtube/limits';
}
