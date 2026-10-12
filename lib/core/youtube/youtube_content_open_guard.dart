import 'package:flutter/material.dart';

import '../explorer/explorer_site.dart';
import '../guard/isle_content_block_guard.dart';
import '../navigation/explorer_entry_guard.dart';
import '../utils/url_parser.dart';
import 'youtube_link_canonical.dart';
import 'youtube_playback_access_guard.dart';

/// 피드·라이브러리·뷰어 — 채널·영상 차단 진입 단일 검사
class YoutubeContentOpenGuard {
  YoutubeContentOpenGuard._();

  static String? denyOpen({
    required String url,
    String? channelId,
    String? channelName,
    String? videoTitle,
  }) {
    final canonical = YoutubeLinkCanonical.normalizeForBlockCheck(url);
    final denyEntry = IsleContentBlockGuard.denyUrl(
      canonical,
      checkYoutubeLimit: true,
      inAppExplorer: true,
    );
    if (denyEntry != null) return denyEntry;

    return YoutubePlaybackAccessGuard.denyPlayback(
      url: canonical,
      videoId: UrlParser.extractYouTubeVideoId(canonical),
      channelId: channelId,
      channelName: channelName,
      videoTitle: videoTitle,
    );
  }

  static bool showDenialOrAllow(
    BuildContext context, {
    required String url,
    String? channelId,
    String? channelName,
    String? videoTitle,
  }) {
    final deny = denyOpen(
      url: url,
      channelId: channelId,
      channelName: channelName,
      videoTitle: videoTitle,
    );
    if (deny == null) return true;
    return ExplorerEntryGuard.showDenial(
      context,
      deny,
      url: url,
      site: ExplorerSite.youtube,
    );
  }
}
