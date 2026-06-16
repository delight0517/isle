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

    double historyBoost(String channelId, String channelName) {
      final id = channelId.trim().toLowerCase();
      final nm = channelName.trim().toLowerCase();
      if (id.isNotEmpty && historyBoosts.containsKey(id)) return historyBoosts[id]!;
      if (nm.isNotEmpty && historyBoosts.containsKey(nm)) return historyBoosts[nm]!;
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

    for (final entry in library) {
      final hist = historyBoost(entry.channelId, entry.channelName);
      final boost = EngagementTracker.boostForUrl(entry.url) +
          EngagementTracker.boostForSourceType(entry.sourceType) +
          hist;
      final item = entry.toFeedItem(relevanceBoost: boost);
      byUrl[entry.url] = hist > 0
          ? item.copyWith(recommendReason: reasonOf(entry.channelId, entry.channelName, hist))
          : item;
    }

    for (final item in remote) {
      final hist = historyBoost(item.channelId, item.channelName);
      final boost = EngagementTracker.boostForUrl(item.url) +
          EngagementTracker.boostForSourceType(item.sourceType) +
          hist;
      final merged = item.copyWith(
        relevanceScore: (item.relevanceScore + boost).clamp(0.0, 1.0),
        summary: item.summary ?? byUrl[item.url]?.summary,
        recommendReason: hist > 0
            ? reasonOf(item.channelId, item.channelName, hist)
            : item.recommendReason,
      );
      byUrl[item.url] = merged;
    }

    var list = byUrl.values.toList();
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list
          .where((i) {
            final hay = '${i.title} ${i.channelName} ${i.summary ?? ''}'.toLowerCase();
            return hay.contains(q);
          })
          .toList();
    }

    list.sort((a, b) {
      final c = b.relevanceScore.compareTo(a.relevanceScore);
      if (c != 0) return c;
      return b.publishedAt.compareTo(a.publishedAt);
    });
    return list;
  }
}
