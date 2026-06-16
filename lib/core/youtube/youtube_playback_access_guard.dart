import '../guard/isle_content_block_guard.dart';
import 'blocked_channel_store.dart';
import 'blocked_url_store.dart';
import 'content_filter_store.dart';
import 'youtube_channel_block_guard.dart';

/// 차단 채널·영상 — WebView·팟캐스트·Focus embed 등 재생 경로 공통
class YoutubePlaybackAccessGuard {
  YoutubePlaybackAccessGuard._();

  static String? denyPlayback({
    String? url,
    String? videoId,
    String? channelId,
    String? channelName,
    String? videoTitle,
    bool checkScheduleAndLimit = true,
  }) {
    final watchUrl = _watchUrl(url: url, videoId: videoId);
    if (watchUrl != null) {
      final deny = IsleContentBlockGuard.denyUrl(
        watchUrl,
        checkYoutubeLimit: checkScheduleAndLimit,
      );
      if (deny != null) return deny;
    }

    final channels = BlockedChannelStore.loadAll();
    final videos = ContentFilterStore.loadVideos();
    final keywords = ContentFilterStore.loadKeywords();
    final blockedUrls = BlockedUrlStore.loadAll();
    if (channels.isEmpty &&
        videos.isEmpty &&
        keywords.isEmpty &&
        blockedUrls.isEmpty) {
      return null;
    }

    final hit = YoutubeChannelBlockGuard.matchProbe(
      channels: channels,
      videos: videos,
      keywords: keywords,
      blockedUrls: blockedUrls,
      channelId: channelId ?? '',
      channelName: channelName ?? '',
      videoId: videoId ?? '',
      videoTitle: videoTitle ?? '',
      url: watchUrl ?? url ?? '',
    );
    return hit?.snackMessage;
  }

  static String? _watchUrl({String? url, String? videoId}) {
    if (url != null && url.trim().isNotEmpty) return url.trim();
    final id = videoId?.trim();
    if (id != null && id.length == 11) {
      return 'https://www.youtube.com/watch?v=$id';
    }
    return null;
  }
}
