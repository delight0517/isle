import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_local_data_sync.dart';
import '../utils/url_parser.dart';
import 'models/insight_card.dart';
import '../../features/feed/data/models/feed_item.dart'; // feed merge only

class InsightPortfolioStore {
  InsightPortfolioStore._();

  static const _boxName = 'isle_insight_portfolio';
  static const _key = 'cards_v1';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('InsightPortfolioStore not open');
    return b;
  }

  static List<InsightCard> loadAll() {
    final raw = box.get(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => InsightCard.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<InsightCard> cards) async {
    await box.put(_key, jsonEncode(cards.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static InsightCard? findByUrl(String url) {
    final norm = url.split('?').first;
    try {
      return loadAll().firstWhere((c) => c.url.split('?').first == norm);
    } catch (_) {
      return null;
    }
  }

  static Future<InsightCard> upsert(InsightCard card) async {
    final list = loadAll();
    final idx = list.indexWhere((e) => e.id == card.id);
    if (idx >= 0) {
      list[idx] = card;
    } else {
      list.insert(0, card);
    }
    await saveAll(list);
    return card;
  }

  static Future<InsightCard?> publish(String id) async {
    final list = loadAll();
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return null;
    final now = DateTime.now();
    list[idx] = list[idx].copyWith(published: true, publishedAt: now);
    await saveAll(list);
    return list[idx];
  }

  static List<InsightCard> published({int limit = 80}) {
    final list = loadAll().where((c) => c.published).toList()
      ..sort((a, b) => (b.publishedAt ?? b.createdAt).compareTo(a.publishedAt ?? a.createdAt));
    if (list.length <= limit) return list;
    return list.sublist(0, limit);
  }

  static List<InsightCard> timeline({int limit = 100}) {
    final list = loadAll()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  static List<FeedItem> publishedAsFeedItems() {
    return published().map((c) {
      final vid = UrlParser.extractYouTubeVideoId(c.url);
      return FeedItem(
        id: 'insight_${c.id}',
        title: c.title,
        url: c.url,
        thumbnailUrl: c.thumbnailUrl,
        sourceType: 'insight',
        channelId: vid ?? '',
        channelName: c.channelName,
        channelAvatar: '',
        detectedTopics: c.keywords,
        relevanceScore: 0.92,
        publishedAt: c.publishedAt ?? c.createdAt,
        summary: c.aiSummaryLines.join('\n'),
        recommendReason: c.oneLiner,
      );
    }).toList();
  }
}
