import 'models/blocked_channel.dart';

/// Safari 확장·rules seed용 채널 pattern 정규화 (4VPN YouTubeChannelPatternNormalizer)
class YoutubeChannelPatternNormalizer {
  YoutubeChannelPatternNormalizer._();

  static List<String> normalizedForExtension(Iterable<BlockedChannel> channels) {
    final out = <String>{};
    for (final c in channels) {
      out.addAll(normalizeEntry(c.channelId));
      out.addAll(normalizeEntry(c.channelName));
    }
    return out.where((e) => e.isNotEmpty).toList()..sort();
  }

  static List<String> normalizeEntry(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return const [];

    if (RegExp(r'^UC[\w-]{10,}$', caseSensitive: false).hasMatch(s)) {
      return [s];
    }
    if (s.startsWith('@')) {
      return [s.toLowerCase()];
    }
    if (RegExp(r'^[a-zA-Z0-9._-]{2,}$').hasMatch(s) && !s.contains(' ')) {
      return ['@${s.toLowerCase()}', s.toLowerCase()];
    }
    return [s.toLowerCase()];
  }
}
