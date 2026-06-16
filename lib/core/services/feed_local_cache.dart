import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../features/feed/data/models/feed_item.dart';

/// Phase 1: 피드 목록 로컬 캐시 (오프라인·에러 시 폴백)
class FeedLocalCache {
  FeedLocalCache._();

  static Box<String> get _box => Hive.box<String>('isle_cache');

  static String _key(String userId, String? topicFilter) =>
      'feed_v1_${userId}_${topicFilter ?? 'all'}';

  static Future<void> save(String userId, String? topicFilter, List<FeedItem> items) async {
    final payload = items.map((e) => e.toJson()).toList();
    await _box.put(_key(userId, topicFilter), jsonEncode(payload));
  }

  static List<FeedItem>? load(String userId, String? topicFilter) {
    final raw = _box.get(_key(userId, topicFilter));
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return null;
    }
  }
}
