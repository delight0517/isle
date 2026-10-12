import '../../features/feed/data/models/feed_item.dart';
import 'engagement_tracker.dart';
import 'models/library_entry.dart';
import 'watch_history_recommender.dart';

/// 원격 피드 + 로컬 라이브러리 + 상호작용 점수 병합
class FeedRanker {
  FeedRanker._();

  static List<FeedItem> merge({
    required List<FeedItem> remote,
    required List<LibraryEntry> library,
    String searchQuery = '',
  }) {
    final byUrl = <String, FeedItem>{};

    // 시청 이력 기반 채널 부스트 (한 번만 계산)
    final historyBoosts = WatchHistoryRecommender.channelBoosts();
    final historyNames = WatchHistoryRecommender.channelNamesByKey();
    final historyTopicBoosts = WatchHistoryRecommender.topicBoosts();

    double historyBoost(String channelId, String channelName) {
      final id = channelId.trim().toLowerCase();
      final nm = channelName.trim().toLowerCase();
      if (id.isNotEmpty && historyBoosts.containsKey(id))
        return historyBoosts[id]!;
      if (nm.isNotEmpty && historyBoosts.containsKey(nm))
        return historyBoosts[nm]!;
      return 0.0;
    }

    String? reasonOf(String channelId, String channelName, double histBoost) {
      if (histBoost <= 0) return null;
      final id = channelId.trim().toLowerCase();
      final nm = channelName.trim().toLowerCase();
      final key = id.isNotEmpty && historyBoosts.containsKey(id) ? id : nm;
      final label = historyNames[key] ?? channelName;
      if (label.isEmpty) return '최근 본 채널';
      return '자주 본 「$label」';
    }

    double topicBoost(Iterable<String> topics) => topics
        .map((topic) => historyTopicBoosts[topic] ?? 0.0)
        .fold(0.0, (best, score) => best > score ? best : score);

    String? topicReason(Iterable<String> topics) {
      final matching = topics
          .where((topic) => (historyTopicBoosts[topic] ?? 0) > 0)
          .toList();
      if (matching.isEmpty) return null;
      matching.sort((a, b) =>
          (historyTopicBoosts[b] ?? 0).compareTo(historyTopicBoosts[a] ?? 0));
      return '최근 시청 주제와 비슷한 「${matching.first}」';
    }

    for (final entry in library) {
      final hist = historyBoost(entry.channelId, entry.channelName);
      final topic = topicBoost(entry.toFeedItem().detectedTopics);
      final boost = EngagementTracker.boostForUrl(entry.url) +
          EngagementTracker.boostForSourceType(entry.sourceType) +
          hist +
          topic;
      final item = entry.toFeedItem(relevanceBoost: boost);
      byUrl[entry.url] = hist > 0
          ? item.copyWith(
              recommendReason:
                  reasonOf(entry.channelId, entry.channelName, hist))
          : topic > 0
              ? item.copyWith(recommendReason: topicReason(item.detectedTopics))
              : item;
    }

    for (final item in remote) {
      final hist = historyBoost(item.channelId, item.channelName);
      final topic = topicBoost(item.detectedTopics);
      final boost = EngagementTracker.boostForUrl(item.url) +
          EngagementTracker.boostForSourceType(item.sourceType) +
          hist +
          topic;
      final merged = item.copyWith(
        relevanceScore: (item.relevanceScore + boost).clamp(0.0, 1.0),
        summary: item.summary ?? byUrl[item.url]?.summary,
        recommendReason: hist > 0
            ? reasonOf(item.channelId, item.channelName, hist)
            : topic > 0
                ? topicReason(item.detectedTopics)
                : item.recommendReason,
      );
      byUrl[item.url] = merged;
    }

    var list = byUrl.values.toList();
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((i) {
        final hay =
            '${i.title} ${i.channelName} ${i.summary ?? ''}'.toLowerCase();
        return hay.contains(q);
      }).toList();
    }

    list.sort((a, b) {
      final c = b.relevanceScore.compareTo(a.relevanceScore);
      if (c != 0) return c;
      return b.publishedAt.compareTo(a.publishedAt);
    });
    return list;
  }
}
