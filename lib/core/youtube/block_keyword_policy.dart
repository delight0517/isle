import '../youtube/models/blocked_channel.dart';

/// 키워드·도메인 차단 — YouTube 플랫폼 URL 오탐·광범위 키워드 오탐 방지
class BlockKeywordPolicy {
  BlockKeywordPolicy._();

  static const maxYoutubeInjectKeywords = 96;
  static const maxYoutubeInjectChannels = 160;

  /// URL·호스트 stem으로 쓰면 모든 youtube.com 주소가 막히는 토큰
  static const platformUrlNoise = {
    'youtube',
    'youtu',
    'youtube.com',
    'youtu.be',
    'm.youtube.com',
    'www.youtube.com',
    'googlevideo',
    'google',
    'www',
    'com',
    'net',
    'org',
  };

  /// 제목 substring 매칭 시 유튜브 홈·검색 전체가 사라지는 단어 (premade @handle 오탐)
  static const youtubeBroadNoise = {
    'shorts',
    'short',
    'video',
    'videos',
    'live',
    'music',
    'official',
    'channel',
    'subscribe',
    'watch',
    'playlist',
    'stream',
    'gaming',
    'game',
    'games',
    'asmr',
    'kpop',
    'haul',
    'ootd',
    'bikini',
    'cosplay',
    'anime',
    'girl',
    'girls',
    'model',
    'models',
    'dance',
    'reel',
    'reels',
    'tiktok',
    'vlog',
    'news',
    'podcast',
    'play',
    'hot',
    'cute',
    'pretty',
    'beautiful',
    'gorgeous',
    'stunning',
    'fit',
    'gym',
    'yoga',
    'tryon',
    'try',
    'swim',
    'swimsuit',
    'beach',
    'pool',
    'summer',
    'vacation',
    'travel',
    'fashion',
    'lookbook',
    'photoshoot',
    'runway',
    'pageant',
    'idol',
    'gravure',
    'maxim',
    'lingerie',
    'waifu',
    'ecchi',
    'cover',
    'remix',
    'trailer',
    'review',
    'tutorial',
    'best',
    'top',
    'new',
    'free',
    'hd',
    '4k',
    'full',
    'feat',
    'mix',
    'album',
    'ep',
    'single',
    'how',
    'show',
    'tv',
    'media',
    'shortsgirls',
    'youtubeshorts',
  };

  /// Safari 항상-차단에 넣으면 Isle·Safari 유튜브 전체가 막힘
  static const neverWebsiteBlockDomains = {
    'youtube.com',
    'youtu.be',
    'googlevideo.com',
    'm.youtube.com',
  };

  static bool isSafeStoredKeyword(String raw) {
    final k = raw.trim().toLowerCase();
    if (k.isEmpty) return false;
    if (platformUrlNoise.contains(k)) return false;
    if (youtubeBroadNoise.contains(k)) return false;
    if (k.startsWith('@') && k.length < 5) return false;
    if (k.length < 3) return false;
    return true;
  }

  static bool isSafePremadeKeyword(String raw) {
    final k = raw.trim().toLowerCase();
    if (!isSafeStoredKeyword(k)) return false;
    if (k.contains('youtube.com') || k.contains('youtu.be')) return false;
    // premade handle slug — 채널 목록으로 이미 차단, 키워드로 넣으면 오탐↑
    if (k.startsWith('@')) return false;
    if (k.length < 4) return false;
    return true;
  }

  static bool isSafePremadeWebsiteDomain(String domain) {
    final d = domain.trim().toLowerCase();
    if (d.isEmpty) return false;
    if (neverWebsiteBlockDomains.contains(d)) return false;
    if (d.endsWith('.youtube.com')) return false;
    return true;
  }

  static List<String> sanitizeStoredKeywords(Iterable<String> raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final item in raw) {
      final k = item.trim().toLowerCase();
      if (!isSafeStoredKeyword(k) || seen.contains(k)) continue;
      seen.add(k);
      out.add(k);
    }
    return out;
  }

  static List<String> sanitizeStoredWebsiteDomains(Iterable<String> raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final item in raw) {
      final d = item.trim().toLowerCase();
      if (!isSafePremadeWebsiteDomain(d) || seen.contains(d)) continue;
      seen.add(d);
      out.add(d);
    }
    return out;
  }

  /// WebView JS 주입 — 길이·개수 상한 (과대 payload → 멈춤·스켈레톤만 보임)
  static List<String> forYoutubeInject(List<String> keywords) {
    final safe = forTitleMatch(keywords);
    if (safe.length <= maxYoutubeInjectKeywords) return safe;
    final sorted = List<String>.from(safe)
      ..sort((a, b) => b.length.compareTo(a.length));
    return sorted.take(maxYoutubeInjectKeywords).toList();
  }

  static List<BlockedChannel> capYoutubeChannels(List<BlockedChannel> channels) {
    if (channels.length <= maxYoutubeInjectChannels) return channels;
    final sorted = List<BlockedChannel>.from(channels)
      ..sort((a, b) => b.blockedAt.compareTo(a.blockedAt));
    return sorted.take(maxYoutubeInjectChannels).toList();
  }

  /// matchUrl — 검색 쿼리·경로만 (호스트 youtube.com 제외)
  static String? keywordInYoutubeUrl(String url, List<String> keywords) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final queryHay = uri.queryParameters.entries
        .where((e) {
          final k = e.key.toLowerCase();
          return k == 'search_query' || k == 'q' || k == 'query';
        })
        .map((e) => e.value)
        .join(' ')
        .toLowerCase();

    final pathHay = uri.path.toLowerCase();
    final hay = queryHay.isNotEmpty ? queryHay : pathHay;
    if (hay.isEmpty || hay == '/') return null;

    for (final kw in keywords) {
      final k = kw.trim().toLowerCase();
      if (!isSafeStoredKeyword(k)) continue;
      if (hay.contains(k)) return kw;
    }
    return null;
  }

  static List<String> forTitleMatch(List<String> keywords) =>
      sanitizeStoredKeywords(keywords);
}
