import 'models/insight_card.dart';
import 'insight_portfolio_store.dart';

class TopicSpike {
  const TopicSpike({required this.label, required this.count, required this.weight});
  final String label;
  final int count;
  final double weight;
}

class LivingIdentitySnapshot {
  const LivingIdentitySnapshot({
    required this.topics,
    required this.keywordCloud,
    required this.totalInsights,
    required this.publishedCount,
    required this.windowStart,
  });

  final List<TopicSpike> topics;
  final List<String> keywordCloud;
  final int totalInsights;
  final int publishedCount;
  final DateTime windowStart;
}

/// 최근 90일 인사이트 → 주제 스파이크·키워드 클라우드
class LivingIdentityService {
  LivingIdentityService._();

  static const _windowDays = 90;

  static LivingIdentitySnapshot build() {
    final cutoff = DateTime.now().subtract(const Duration(days: _windowDays));
    final cards = InsightPortfolioStore.loadAll()
        .where((c) => c.createdAt.isAfter(cutoff))
        .toList();

    final counts = <String, int>{};
    for (final c in cards) {
      for (final k in c.keywords) {
        final t = k.trim();
        if (t.isEmpty) continue;
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }

    final max = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    final spikes = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topics = spikes.take(8).map((e) {
      final w = max > 0 ? e.value / max : 0.0;
      return TopicSpike(label: e.key, count: e.value, weight: w);
    }).toList();

    final cloud = spikes.take(14).map((e) => e.key).toList();

    return LivingIdentitySnapshot(
      topics: topics,
      keywordCloud: cloud,
      totalInsights: cards.length,
      publishedCount: cards.where((c) => c.published).length,
      windowStart: cutoff,
    );
  }

  static List<InsightCard> recentTimeline({int limit = 40}) =>
      InsightPortfolioStore.timeline(limit: limit);
}
