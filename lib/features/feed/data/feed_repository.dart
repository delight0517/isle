import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/env.dart';
import '../../../core/utils/topic_matcher.dart';
import 'models/feed_item.dart';

class FeedRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// 서버/로컬 더미·샘플 카드 (예시 피드)
  static bool isDemoItem(FeedItem item) =>
      item.id.startsWith('dummy_') || item.url.contains('example');

  /// 서버 `relevance_score`와 유저 관심사 태그를 합성해 재정렬
  static List<FeedItem> applyUserInterestRanking(List<FeedItem> items, List<String> userTags) {
    if (userTags.isEmpty) return items;
    final ranked = items
        .map((e) {
          final boost = TopicMatcher.score(e.detectedTopics, userTags);
          final merged = (e.relevanceScore * 0.55 + boost * 0.45).clamp(0.0, 1.0);
          return e.copyWith(relevanceScore: merged);
        })
        .toList()
      ..sort((a, b) {
        final c = b.relevanceScore.compareTo(a.relevanceScore);
        if (c != 0) return c;
        return b.publishedAt.compareTo(a.publishedAt);
      });
    return ranked;
  }

  Future<List<FeedItem>> getFeed({
    required String userId,
    int page = 0,
    int limit = 20,
    String? topicFilter,
    List<String> userInterestTags = const [],
  }) async {
    if (!Env.isSupabaseConfigured || userId.isEmpty) {
      return [];
    }
    var query = _client
        .from('feed_cache')
        .select()
        .eq('user_id', userId)
        .order('relevance_score', ascending: false)
        .order('published_at', ascending: false)
        .range(page * limit, (page + 1) * limit - 1);

    final res = await query;
    var items = (res as List).map((e) => FeedItem.fromJson(e as Map<String, dynamic>)).toList();

    if (topicFilter != null) {
      items = items.where((i) => i.detectedTopics.contains(topicFilter)).toList();
    }
    return applyUserInterestRanking(items, userInterestTags);
  }

  Future<void> dismissItem(String userId, String contentUrl) async {
    if (!Env.isSupabaseConfigured) return;
    await _client.from('feed_cache').update({'relevance_score': 0.0}).eq('user_id', userId).eq('content_url', contentUrl);
  }

  static List<FeedItem> dummyFeed() => List.generate(
        8,
        (i) => FeedItem(
          id: 'dummy_$i',
          title: [
            'Flutter로 아름다운 UI 만들기',
            '2026 재테크 트렌드',
            '디자인 시스템의 모든 것',
            'AI 시대의 생산성',
            '제주 한 달 살기 후기',
            '클래식 음악 입문 가이드',
            'Supabase vs Firebase 비교',
            '철학으로 풀어보는 일상',
          ][i % 8],
          url: 'https://youtube.com/watch?v=example$i',
          thumbnailUrl: 'https://picsum.photos/seed/$i/400/225',
          sourceType: i % 3 == 0 ? 'youtube' : 'article',
          channelId: 'ch_$i',
          channelName: [
            '개발자 민수',
            '경제연구소',
            '디자인랩',
            'AI투데이',
            '여행하는 지은',
            '클래식웨이브',
            '테크인사이트',
            '철학카페',
          ][i % 8],
          channelAvatar: 'https://picsum.photos/seed/av$i/50/50',
          detectedTopics: [
            [
              '기술/IT',
              '재무/투자',
              '디자인',
              '자기계발',
              '라이프스타일',
              '음악',
              '기술/IT',
              '철학/인문',
            ][i % 8],
          ],
          relevanceScore: 0.5 + (i * 0.05),
          publishedAt: DateTime.now().subtract(Duration(hours: i * 3)),
        ),
      );
}
