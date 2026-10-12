import 'blocked_channel_store.dart';
import 'blocked_url_store.dart';
import 'content_filter_store.dart';
import 'models/youtube_page_channel.dart';
import 'youtube_channel_block_guard.dart';

/// 피드 최소화(park) WebView — 차단 채널·영상 백그라운드 재생 방지
class YoutubeParkedBlockGuard {
  YoutubeParkedBlockGuard._();

  static YoutubeBlockHit? match({
    required String url,
    required YoutubePageChannel probe,
  }) {
    return YoutubeChannelBlockGuard.matchProbe(
      channels: BlockedChannelStore.loadAll(),
      videos: ContentFilterStore.loadVideos(),
      keywords: ContentFilterStore.loadKeywords(),
      blockedUrls: BlockedUrlStore.loadAll(),
      channelId: probe.channelId,
      channelName: probe.channelName,
      videoId: probe.videoId,
      videoTitle: probe.videoTitle,
      url: url,
    );
  }
}
