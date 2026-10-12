import '../utils/url_parser.dart';
import 'youtube_link_canonical.dart';
import 'block_keyword_policy.dart';
import 'blocked_url_guard.dart';
import 'models/blocked_channel.dart';
import 'models/blocked_url.dart';
import 'models/blocked_video.dart';

/// Isle YouTube·Safari YouTube — URL·채널 프로브 차단 판별
class YoutubeChannelBlockGuard {
  YoutubeChannelBlockGuard._();

  static YoutubeBlockHit? matchUrl(
    String url, {
    required List<BlockedChannel> channels,
    required List<BlockedVideo> videos,
    required List<String> keywords,
    List<BlockedUrl> blockedUrls = const [],
  }) {
    url = YoutubeLinkCanonical.normalizeForBlockCheck(url);
    final urlHit = BlockedUrlGuard.match(url, blockedUrls);
    if (urlHit != null) {
      return YoutubeBlockHit(kind: YoutubeBlockKind.url, label: urlHit.label);
    }

    final lower = url.toLowerCase();
    if (!lower.contains('youtube.com') && !lower.contains('youtu.be')) {
      return null;
    }

    final vid = UrlParser.extractYouTubeVideoId(url);
    if (vid != null && videos.any((v) => v.videoId == vid)) {
      return YoutubeBlockHit(kind: YoutubeBlockKind.video, label: '숨긴 영상');
    }

    final kwHit = BlockKeywordPolicy.keywordInYoutubeUrl(url, keywords);
    if (kwHit != null) {
      return YoutubeBlockHit(kind: YoutubeBlockKind.keyword, label: kwHit);
    }

    final keys = _channelKeysFromUrl(url);
    for (final ch in channels) {
      if (_channelKeysMatch(ch, keys)) {
        return YoutubeBlockHit(
          kind: YoutubeBlockKind.channel,
          label: ch.channelName.isNotEmpty ? ch.channelName : ch.channelId,
        );
      }
    }
    return null;
  }

  static YoutubeBlockHit? matchProbe({
    required List<BlockedChannel> channels,
    required List<BlockedVideo> videos,
    required List<String> keywords,
    List<BlockedUrl> blockedUrls = const [],
    String channelId = '',
    String channelName = '',
    String videoId = '',
    String videoTitle = '',
    String url = '',
  }) {
    if (url.isNotEmpty) {
      url = YoutubeLinkCanonical.normalizeForBlockCheck(url);
    }
    if (url.isNotEmpty) {
      final urlHit = BlockedUrlGuard.match(url, blockedUrls);
      if (urlHit != null) {
        return YoutubeBlockHit(kind: YoutubeBlockKind.url, label: urlHit.label);
      }
    }
    if (videoId.length == 11) {
      for (final u in blockedUrls) {
        if (u.youtubeVideoId == videoId) {
          return YoutubeBlockHit(kind: YoutubeBlockKind.url, label: u.label ?? '숨긴 URL');
        }
      }
    }

    if (videoId.length == 11 && videos.any((v) => v.videoId == videoId)) {
      return YoutubeBlockHit(kind: YoutubeBlockKind.video, label: '숨긴 영상');
    }

    final hay = '${videoTitle} ${channelName}'.toLowerCase();
    for (final kw in BlockKeywordPolicy.forTitleMatch(keywords)) {
      final k = kw.trim().toLowerCase();
      if (k.isNotEmpty && hay.contains(k)) {
        return YoutubeBlockHit(kind: YoutubeBlockKind.keyword, label: kw);
      }
    }

    final ref = FeedChannelRef(channelId: channelId, channelName: channelName);
    for (final ch in channels) {
      if (ch.matches(ref)) {
        return YoutubeBlockHit(
          kind: YoutubeBlockKind.channel,
          label: channelName.isNotEmpty ? channelName : ch.channelName,
        );
      }
    }

    if (url.isNotEmpty) {
      return matchUrl(
        url,
        channels: channels,
        videos: videos,
        keywords: keywords,
        blockedUrls: blockedUrls,
      );
    }
    return null;
  }

  static Set<String> _channelKeysFromUrl(String url) {
    final keys = <String>{};
    final uri = Uri.tryParse(url);
    if (uri == null) return keys;
    final path = uri.path.toLowerCase();
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (path.contains('/channel/') && segments.length >= 2) {
      final i = segments.indexOf('channel');
      if (i >= 0 && i + 1 < segments.length) keys.add(_norm(segments[i + 1]));
    }
    if (path.contains('/@') && segments.isNotEmpty) {
      final h = segments.first;
      if (h.startsWith('@')) {
        keys.add(_norm(h));
        keys.add(_norm(h.substring(1)));
      }
    }
    if (segments.length >= 2) {
      final tag = segments[0];
      if (tag == 'c' || tag == 'user') keys.add(_norm(segments[1]));
    }
    final cid = uri.queryParameters['channel_id'] ?? uri.queryParameters['uc'];
    if (cid != null && cid.trim().isNotEmpty) {
      keys.add(_norm(cid));
    }
    return keys;
  }

  static bool _channelKeysMatch(BlockedChannel ch, Set<String> keys) {
    if (keys.isEmpty) return false;
    final id = _norm(ch.channelId);
    final name = _norm(ch.channelName);
    if (id.isNotEmpty) {
      if (keys.contains(id)) return true;
      final bare = id.startsWith('@') ? id.substring(1) : id;
      if (keys.contains(bare) || keys.contains('@$bare')) return true;
    }
    if (name.isNotEmpty && keys.contains(name)) return true;
    return false;
  }

  static String _norm(String s) => s.toLowerCase().trim();
}

enum YoutubeBlockKind { channel, video, keyword, url }

class YoutubeBlockHit {
  const YoutubeBlockHit({required this.kind, required this.label});

  final YoutubeBlockKind kind;
  final String label;

  String get snackMessage {
    switch (kind) {
      case YoutubeBlockKind.channel:
        return '차단한 채널이에요 · $label';
      case YoutubeBlockKind.video:
        return '숨긴 영상이에요';
      case YoutubeBlockKind.keyword:
        return '차단 키워드가 포함된 영상이에요 · $label';
      case YoutubeBlockKind.url:
        return '차단한 URL이에요 · $label';
    }
  }
}
