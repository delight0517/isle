import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/env.dart';
import '../../../core/utils/topic_matcher.dart';
import '../../../core/utils/url_parser.dart';
import '../../feed/data/models/feed_item.dart';

class ArchiveRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> insertArchive(Map<String, dynamic> row) async {
    if (!Env.isSupabaseConfigured) return;
    await _client.from('archives').insert(row);
  }

  /// URL 직접 입력(브런치·기사 등) 아카이브
  Future<void> insertManualArchive({
    required String userId,
    required String url,
    required String title,
    String? thumbnailUrl,
  }) async {
    if (!Env.isSupabaseConfigured) return;
    final tags = TopicMatcher.detectTopics(title);
    await _client.from('archives').insert({
      'user_id': userId,
      'url': url,
      'title': title,
      'thumbnail_url': thumbnailUrl,
      'source_type': UrlParser.detectSourceType(url),
      'tags': tags,
    });
  }

  /// 피드 카드 스와이프 저장 → `archives` 행 생성
  Future<void> insertFromFeedItem({
    required String userId,
    required FeedItem item,
    String? shelfId,
  }) async {
    if (!Env.isSupabaseConfigured) return;
    final fromTitle = TopicMatcher.detectTopics(item.title);
    final merged = {...item.detectedTopics, ...fromTitle}.toList();
    await _client.from('archives').insert({
      'user_id': userId,
      'shelf_id': shelfId,
      'url': item.url,
      'title': item.title,
      'thumbnail_url': item.thumbnailUrl.isEmpty ? null : item.thumbnailUrl,
      'source_type': UrlParser.detectSourceType(item.url),
      'source_channel_id': item.channelId.isEmpty ? null : item.channelId,
      'tags': merged,
    });
  }
}
