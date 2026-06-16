import 'package:dio/dio.dart';

import '../library/models/connected_source.dart';
/// URL 붙여넣기 → 구독 소스 + RSS 주소
class FeedSourceResolver {
  FeedSourceResolver._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        'Accept-Language': 'ko-KR,ko;q=0.9,en;q=0.8',
      },
    ),
  );

  static Future<ResolvedFeedSource?> resolve(String rawInput) async {
    var input = rawInput.trim();
    if (input.isEmpty) return null;
    if (!input.startsWith('http')) input = 'https://$input';

    final uri = Uri.tryParse(input);
    if (uri == null) return null;

    if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
      return _resolveYoutube(input);
    }
    if (uri.host.contains('brunch.co.kr')) {
      return ResolvedFeedSource(
        source: ConnectedSource(
          id: 'src_${DateTime.now().millisecondsSinceEpoch}',
          type: 'brunch',
          profileUrl: input.split('?').first,
          displayName: _displayFromUrl(input),
          addedAt: DateTime.now(),
        ),
        fetchKind: FeedFetchKind.brunchProfile,
      );
    }
    if (_looksLikeRss(input)) {
      return ResolvedFeedSource(
        source: ConnectedSource(
          id: 'src_${DateTime.now().millisecondsSinceEpoch}',
          type: 'rss',
          profileUrl: input,
          displayName: _displayFromUrl(input),
          addedAt: DateTime.now(),
        ),
        rssUrl: input,
        fetchKind: FeedFetchKind.rss,
      );
    }

    return null;
  }

  static bool _looksLikeRss(String url) =>
      url.contains('/feed') || url.endsWith('.xml') || url.contains('rss');

  static Future<ResolvedFeedSource?> _resolveYoutube(String url) async {
    var channelId = _channelIdFromUrl(url);
    String? handle;
    if (url.contains('/@')) {
      final m = RegExp(r'/@([\w.-]+)').firstMatch(url);
      handle = m?.group(1);
    }

    if (channelId == null && handle != null) {
      channelId = await _scrapeChannelId('https://www.youtube.com/@$handle');
    }
    if (channelId == null && url.contains('/channel/')) {
      channelId = RegExp(r'/channel/(UC[\w-]+)').firstMatch(url)?.group(1);
    }

    if (channelId == null) return null;

    final display = handle ?? channelId;
    final profile = handle != null ? 'https://www.youtube.com/@$handle' : 'https://www.youtube.com/channel/$channelId';

    return ResolvedFeedSource(
      source: ConnectedSource(
        id: 'yt_$channelId',
        type: 'youtube',
        profileUrl: profile,
        displayName: display,
        addedAt: DateTime.now(),
      ),
      rssUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId',
      fetchKind: FeedFetchKind.rss,
      youtubeChannelId: channelId,
    );
  }

  static String? _channelIdFromUrl(String url) {
    final m = RegExp(r'/channel/(UC[\w-]+)').firstMatch(url);
    return m?.group(1);
  }

  static Future<String?> _scrapeChannelId(String pageUrl) async {
    try {
      final res = await _dio.get<String>(pageUrl);
      final html = res.data ?? '';
      final patterns = [
        RegExp(r'"channelId":"(UC[\w-]+)"'),
        RegExp(r'"externalId":"(UC[\w-]+)"'),
        RegExp(r'channel_id=(UC[\w-]+)'),
      ];
      for (final p in patterns) {
        final m = p.firstMatch(html);
        if (m != null) return m.group(1);
      }
    } catch (_) {}
    return null;
  }

  static String _displayFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (seg.isEmpty) return uri.host;
    return seg.last.replaceAll('@', '');
  }
}

enum FeedFetchKind { rss, brunchProfile }

class ResolvedFeedSource {
  const ResolvedFeedSource({
    required this.source,
    required this.fetchKind,
    this.rssUrl,
    this.youtubeChannelId,
  });

  final ConnectedSource source;
  final FeedFetchKind fetchKind;
  final String? rssUrl;
  final String? youtubeChannelId;
}
