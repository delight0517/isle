import 'package:hive_flutter/hive_flutter.dart';

/// Safari·Chrome 유튜브 차단 → Isle WebView 시청·트래킹 유도 상태
class BrowserYoutubeTrackingPrefs {
  BrowserYoutubeTrackingPrefs._();

  static const _prefix = 'isle_browser_yt_track_';

  static Box<String> get _box => Hive.box<String>('isle_cache');

  /// 설정 마법사 완료(3단계 중 사용자가 「완료」 누름)
  static bool get hasCompletedEncouragementFlow =>
      _box.get('${_prefix}flow_done') == 'true';

  static Future<void> setCompletedEncouragementFlow(bool v) =>
      _box.put('${_prefix}flow_done', v ? 'true' : 'false');

  /// iOS OS 차단 적용 성공 기록
  static bool get osWebBlockApplied =>
      _box.get('${_prefix}os_block_applied') == 'true';

  static Future<void> setOsWebBlockApplied(bool v) =>
      _box.put('${_prefix}os_block_applied', v ? 'true' : 'false');

  /// 피드 배너 닫기
  static bool get feedBannerDismissed =>
      _box.get('${_prefix}feed_banner_off') == 'true';

  static Future<void> setFeedBannerDismissed(bool v) =>
      _box.put('${_prefix}feed_banner_off', v ? 'true' : 'false');

  static bool get shouldShowFeedBanner =>
      !feedBannerDismissed && !hasCompletedEncouragementFlow;

  /// 앱 투어 종료 후 설정 마법사 1회 유도 완료
  static bool get postTourSetupPrompted =>
      _box.get('${_prefix}post_tour_prompt') == 'true';

  static Future<void> setPostTourSetupPrompted(bool v) =>
      _box.put('${_prefix}post_tour_prompt', v ? 'true' : 'false');
}
