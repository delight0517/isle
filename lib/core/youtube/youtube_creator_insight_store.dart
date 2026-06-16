import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'models/youtube_creator_insight.dart';

/// 최근 분석 기록 (로컬)
class YoutubeCreatorInsightStore {
  YoutubeCreatorInsightStore._();

  static const _boxName = 'isle_yt_creator_insights';
  static const _listKey = 'recent_v1';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Future<void> save(YoutubeCreatorInsight insight) async {
    await ensureOpen();
    final list = loadRecent();
    list.removeWhere((e) => e.videoId == insight.videoId);
    list.insert(0, insight);
    final trimmed = list.take(15).toList();
    await _box!.put(
      _listKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  static List<YoutubeCreatorInsight> loadRecent() {
    if (_box == null || !_box!.isOpen) return [];
    final raw = _box!.get(_listKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => YoutubeCreatorInsight.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
