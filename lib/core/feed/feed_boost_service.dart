import '../../features/feed/data/models/feed_item.dart';
import 'feed_boost_store.dart';
import 'models/feed_boost_preference.dart';

/// 저장된 채널·장르 선호를 피드 relevance에 반영
class FeedBoostService {
  FeedBoostService._();

  static List<FeedItem> applyBoosts(
    List<FeedItem> items, {
    List<FeedBoostChannel>? channels,
    List<FeedBoostGenre>? genres,
  }) {
    final ch = channels ?? FeedBoostStore.loadChannels();
    final ge = genres ?? FeedBoostStore.loadGenres();
    if (ch.isEmpty && ge.isEmpty) return items;

    final boosted = items.map((item) {
      var add = 0.0;

      for (final c in ch) {
        if (c.matches(id: item.channelId, name: item.channelName)) {
          add += 0.22 * c.weight;
        }
      }

      for (final g in ge) {
        final s = g.scoreForItem(
          title: item.title,
          channelName: item.channelName,
          detectedTopics: item.detectedTopics,
        );
        if (s > 0.15) add += 0.18 * s * g.weight;
      }

      if (add <= 0) return item;

      String? reason;
      for (final c in ch) {
        if (c.matches(id: item.channelId, name: item.channelName)) {
          final name = item.channelName.isNotEmpty ? item.channelName : '저장한 채널';
          reason = '저장한 「$name」';
          break;
        }
      }
      if (reason == null) {
        for (final g in ge) {
          final s = g.scoreForItem(
            title: item.title,
            channelName: item.channelName,
            detectedTopics: item.detectedTopics,
          );
          if (s > 0.15) {
            reason = '장르·스타일 「${g.label}」';
            break;
          }
        }
      }

      return item.copyWith(
        relevanceScore: (item.relevanceScore + add).clamp(0.0, 1.0),
        recommendReason: reason ?? item.recommendReason,
      );
    }).toList();

    boosted.sort((a, b) {
      final c = b.relevanceScore.compareTo(a.relevanceScore);
      if (c != 0) return c;
      return b.publishedAt.compareTo(a.publishedAt);
    });
    return boosted;
  }
}
