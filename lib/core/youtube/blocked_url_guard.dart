import '../utils/url_parser.dart';
import 'models/blocked_url.dart';

/// URL 정규화 — 차단 목록·매칭 단일 출처
class BlockedUrlNormalize {
  BlockedUrlNormalize._();

  static const _stripQueryKeys = {
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'fbclid',
    'gclid',
    'si',
  };

  static String? canonical(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return null;
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;

    final ytId = UrlParser.extractYouTubeVideoId(url);
    if (ytId != null && ytId.length == 11) {
      return 'https://www.youtube.com/watch?v=$ytId';
    }

    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final qp = <String, String>{};
    uri.queryParameters.forEach((k, v) {
      if (!_stripQueryKeys.contains(k.toLowerCase())) qp[k] = v;
    });
    var path = uri.path;
    if (path.isEmpty) path = '/';
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return Uri(
      scheme: 'https',
      host: host,
      path: path,
      queryParameters: qp.isEmpty ? null : qp,
    ).toString();
  }

  static String? domain(String raw) {
    final c = canonical(raw);
    if (c == null) return null;
    final host = Uri.tryParse(c)?.host;
    if (host == null || host.isEmpty) return null;
    return host.replaceFirst(RegExp(r'^www\.'), '');
  }
}

/// 차단 URL 목록 — Isle 피드·YouTube·Google 표면·네비게이션 공통
class BlockedUrlGuard {
  BlockedUrlGuard._();

  static BlockedUrlHit? match(String? raw, List<BlockedUrl> entries) {
    if (raw == null || raw.trim().isEmpty || entries.isEmpty) return null;
    final canonical = BlockedUrlNormalize.canonical(raw);
    if (canonical == null) return null;

    final vid = UrlParser.extractYouTubeVideoId(canonical);
    for (final e in entries) {
      if (e.canonicalUrl == canonical) {
        return BlockedUrlHit(url: e.canonicalUrl, label: e.label ?? _shortLabel(e));
      }
      if (vid != null &&
          e.youtubeVideoId != null &&
          e.youtubeVideoId == vid) {
        return BlockedUrlHit(url: e.canonicalUrl, label: e.label ?? '숨긴 영상');
      }
    }
    return null;
  }

  static String _shortLabel(BlockedUrl e) {
    if (e.youtubeVideoId != null) return '숨긴 YouTube 영상';
    final host = Uri.tryParse(e.canonicalUrl)?.host ?? e.canonicalUrl;
    return host;
  }

  /// JS 주입용 — canonical URL + YouTube videoId
  static ({List<String> urls, List<String> videoIds}) jsPayload(
    List<BlockedUrl> entries,
  ) {
    final urls = <String>{};
    final vids = <String>{};
    for (final e in entries) {
      if (e.canonicalUrl.isNotEmpty) urls.add(e.canonicalUrl);
      if (e.youtubeVideoId != null && e.youtubeVideoId!.length == 11) {
        vids.add(e.youtubeVideoId!);
      }
    }
    return (urls: urls.toList(), videoIds: vids.toList());
  }
}

class BlockedUrlHit {
  const BlockedUrlHit({required this.url, required this.label});

  final String url;
  final String label;

  String get snackMessage => '차단한 URL이에요 · $label';
}
