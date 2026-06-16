import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../features/feed/data/models/feed_item.dart';

/// 네트워크에서 가져온 피드 캐시 (API 없음)
class FeedIngestStore {
  FeedIngestStore._();

  static const _boxName = 'isle_feed_ingest';
  static const _itemsKey = 'items_v1';
  static const _lastRefreshKey = 'last_refresh_at';
  static const _lastStatusKey = 'last_status';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('FeedIngestStore not open');
    return b;
  }

  static List<FeedItem> load() {
    final raw = box.get(_itemsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<FeedItem> items) async {
    final payload = items.map((e) => e.toJson()).toList();
    await box.put(_itemsKey, jsonEncode(payload));
  }

  static DateTime? get lastRefreshAt {
    final raw = box.get(_lastRefreshKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> setLastRefresh(DateTime at, {String? status}) async {
    await box.put(_lastRefreshKey, at.toIso8601String());
    if (status != null) {
      await box.put(_lastStatusKey, status);
    }
  }

  static String? get lastStatus => box.get(_lastStatusKey);
}
