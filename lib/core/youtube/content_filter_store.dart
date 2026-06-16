import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../block/models/pending_rule_removal.dart';
import '../block/rule_pending_removal_store.dart';
import '../services/isle_local_data_sync.dart';
import 'blocked_url_store.dart';
import 'models/blocked_url.dart';
import 'models/blocked_video.dart';
import 'youtube_block_rules_sync.dart';
import 'block_keyword_policy.dart';

const _boxName = 'isle_content_filters';
const _videosKey = 'blocked_videos_v1';
const _keywordsKey = 'blocked_keywords_v1';

class ContentFilterStore {
  ContentFilterStore._();

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('ContentFilterStore not initialized');
    }
    return b;
  }

  static List<BlockedVideo> loadVideos() {
    final raw = box.get(_videosKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => BlockedVideo.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((v) => v.videoId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveVideos(List<BlockedVideo> list) async {
    await box.put(_videosKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static List<String> loadKeywords() {
    final raw = box.get(_keywordsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = list
          .map((e) => (e as String).trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
      return BlockKeywordPolicy.sanitizeStoredKeywords(parsed);
    } catch (_) {
      return [];
    }
  }

  /// premade 팩 오탐 키워드(youtube 등) — 1회 정리
  static Future<void> ensureKeywordsSanitized() async {
    final raw = box.get(_keywordsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = list
          .map((e) => (e as String).trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
      final clean = BlockKeywordPolicy.sanitizeStoredKeywords(parsed);
      if (clean.length != parsed.length) {
        await saveKeywords(clean);
      }
    } catch (_) {}
  }

  static Future<void> saveKeywords(List<String> list) async {
    final unique = <String>{};
    for (final k in BlockKeywordPolicy.sanitizeStoredKeywords(list)) {
      unique.add(k);
    }
    await box.put(_keywordsKey, jsonEncode(unique.toList()..sort()));
    isleNotifyLocalDataChanged();
  }
}

final blockedVideosProvider =
    StateNotifierProvider<BlockedVideosNotifier, List<BlockedVideo>>((ref) => BlockedVideosNotifier());

class BlockedVideosNotifier extends StateNotifier<List<BlockedVideo>> {
  BlockedVideosNotifier() : super(ContentFilterStore.loadVideos());

  Future<void> reload() async {
    state = ContentFilterStore.loadVideos();
  }

  Future<void> addVideo(String videoId, {String? sourceUrl}) async {
    final id = videoId.trim();
    if (id.length != 11) return;
    final list = ContentFilterStore.loadVideos();
    if (list.any((v) => v.videoId == id)) return;
    list.add(BlockedVideo(videoId: id, sourceUrl: sourceUrl, blockedAt: DateTime.now()));
    await ContentFilterStore.saveVideos(list);
    state = ContentFilterStore.loadVideos();
    if (sourceUrl != null && sourceUrl.trim().isNotEmpty) {
      await BlockedUrlStore.add(sourceUrl);
    }
    YoutubeBlockRulesSync.scheduleExport();
  }

  Future<void> removeVideo(String videoId) async {
    final list = ContentFilterStore.loadVideos()..removeWhere((v) => v.videoId == videoId);
    await ContentFilterStore.saveVideos(list);
    state = list;
    YoutubeBlockRulesSync.scheduleExport();
  }
}

final blockedKeywordsProvider =
    StateNotifierProvider<BlockedKeywordsNotifier, List<String>>((ref) => BlockedKeywordsNotifier());

class BlockedKeywordsNotifier extends StateNotifier<List<String>> {
  BlockedKeywordsNotifier() : super(ContentFilterStore.loadKeywords());

  Future<void> reload() async {
    state = ContentFilterStore.loadKeywords();
  }

  Future<void> setAll(List<String> keywords) async {
    await ContentFilterStore.saveKeywords(keywords);
    state = ContentFilterStore.loadKeywords();
    YoutubeBlockRulesSync.scheduleExport();
  }

  Future<void> add(String keyword) async {
    final t = keyword.trim().toLowerCase();
    if (t.isEmpty) return;
    await RulePendingRemovalStore.cancelKind(PendingRuleRemovalKind.keyword, t);
    final list = List<String>.from(state);
    if (list.contains(t)) return;
    list.add(t);
    await setAll(list);
  }

  Future<void> remove(String keyword) async {
    final t = keyword.trim().toLowerCase();
    final list = state.where((k) => k != t).toList();
    await setAll(list);
  }
}
