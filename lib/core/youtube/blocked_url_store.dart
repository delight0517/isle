import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_local_data_sync.dart';
import '../utils/url_parser.dart';
import '../block/models/pending_rule_removal.dart';
import '../block/rule_pending_removal_store.dart';
import 'blocked_url_guard.dart';
import 'models/blocked_url.dart';
import 'youtube_block_rules_sync.dart';

const _boxName = 'isle_blocked_urls';
const _urlsKey = 'urls_v1';

class BlockedUrlStore {
  BlockedUrlStore._();

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('BlockedUrlStore.ensureOpen() first');
    }
    return b;
  }

  static List<BlockedUrl> loadAll() {
    final raw = box.get(_urlsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => BlockedUrl.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((u) => u.canonicalUrl.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<BlockedUrl> list) async {
    await box.put(_urlsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static Future<bool> add(String raw, {String? label}) async {
    final canonical = BlockedUrlNormalize.canonical(raw);
    if (canonical == null) return false;
    final list = loadAll();
    if (list.any((e) => e.canonicalUrl == canonical)) return true;
    final vid = UrlParser.extractYouTubeVideoId(canonical);
    list.add(
      BlockedUrl(
        canonicalUrl: canonical,
        label: label?.trim().isNotEmpty == true ? label!.trim() : null,
        youtubeVideoId: vid,
        blockedAt: DateTime.now(),
      ),
    );
    await saveAll(list);
    YoutubeBlockRulesSync.scheduleExport();
    return true;
  }

  static Future<void> remove(String canonicalUrl) async {
    final list = loadAll()..removeWhere((e) => e.canonicalUrl == canonicalUrl);
    await saveAll(list);
    YoutubeBlockRulesSync.scheduleExport();
  }
}

final blockedUrlsProvider =
    StateNotifierProvider<BlockedUrlsNotifier, List<BlockedUrl>>(
  (ref) => BlockedUrlsNotifier(),
);

class BlockedUrlsNotifier extends StateNotifier<List<BlockedUrl>> {
  BlockedUrlsNotifier() : super(BlockedUrlStore.loadAll());

  Future<void> reload() async {
    state = BlockedUrlStore.loadAll();
  }

  Future<bool> add(String raw, {String? label}) async {
    final canonical = BlockedUrlNormalize.canonical(raw);
    if (canonical != null) {
      await RulePendingRemovalStore.cancelKind(PendingRuleRemovalKind.blockedUrl, canonical);
    }
    final ok = await BlockedUrlStore.add(raw, label: label);
    if (ok) state = BlockedUrlStore.loadAll();
    return ok;
  }

  Future<void> remove(String canonicalUrl) async {
    await BlockedUrlStore.remove(canonicalUrl);
    state = BlockedUrlStore.loadAll();
  }
}
