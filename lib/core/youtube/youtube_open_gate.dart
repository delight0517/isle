import '../explorer/explorer_site.dart';
import '../guard/isle_block_boundary.dart';
import 'youtube_content_open_guard.dart';

/// YouTube 전용 — [IsleBlockBoundary]의 youtube 표면 래퍼
class YoutubeOpenGate {
  YoutubeOpenGate._();

  /// `/youtube` 진입
  static String? denyDedicatedTab({String? url}) =>
      IsleBlockBoundary.denyEntry(site: ExplorerSite.youtube, url: url);

  /// URL 재생 — 시청 게이트 + 콘텐츠 필터
  static String? denyPlayback({
    required String url,
    String? channelId,
    String? channelName,
    String? videoTitle,
  }) =>
      YoutubeContentOpenGuard.denyOpen(
        url: url,
        channelId: channelId,
        channelName: channelName,
        videoTitle: videoTitle,
      );

  static bool shouldApplyScheduleDomainShield(ExplorerSite site, {String? url}) =>
      IsleBlockBoundary.appliesScheduleDomainShield(site, url: url);
}
