import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_local_data_sync.dart';

class SharedPlaylistItem {
  const SharedPlaylistItem({
    required this.id,
    required this.url,
    required this.title,
    required this.thumbnailUrl,
    required this.sourceType,
    required this.addedAt,
    this.channelName = '',
    this.transcript,
    this.articleBody,
    this.ccSyncedAt,
  });

  final String id;
  final String url;
  final String title;
  final String thumbnailUrl;
  final String sourceType;
  final DateTime addedAt;
  final String channelName;
  final String? transcript;
  final String? articleBody;
  final DateTime? ccSyncedAt;

  bool get hasTranscript => (transcript?.trim().length ?? 0) >= 40;
  bool get hasArticle => (articleBody?.trim().length ?? 0) >= 80;

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'thumbnail_url': thumbnailUrl,
        'source_type': sourceType,
        'added_at': addedAt.toIso8601String(),
        'channel_name': channelName,
        if (transcript != null) 'transcript': transcript,
        if (articleBody != null) 'article_body': articleBody,
        if (ccSyncedAt != null) 'cc_synced_at': ccSyncedAt!.toIso8601String(),
      };

  factory SharedPlaylistItem.fromJson(Map<String, dynamic> j) => SharedPlaylistItem(
        id: j['id'] as String? ?? '',
        url: j['url'] as String? ?? '',
        title: j['title'] as String? ?? '',
        thumbnailUrl: j['thumbnail_url'] as String? ?? '',
        sourceType: j['source_type'] as String? ?? 'article',
        addedAt: DateTime.tryParse(j['added_at'] as String? ?? '') ?? DateTime.now(),
        channelName: j['channel_name'] as String? ?? '',
        transcript: j['transcript'] as String?,
        articleBody: j['article_body'] as String?,
        ccSyncedAt: DateTime.tryParse(j['cc_synced_at'] as String? ?? ''),
      );

  SharedPlaylistItem copyWith({
    String? title,
    String? thumbnailUrl,
    String? channelName,
    String? transcript,
    String? articleBody,
    DateTime? ccSyncedAt,
  }) =>
      SharedPlaylistItem(
        id: id,
        url: url,
        title: title ?? this.title,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        sourceType: sourceType,
        addedAt: addedAt,
        channelName: channelName ?? this.channelName,
        transcript: transcript ?? this.transcript,
        articleBody: articleBody ?? this.articleBody,
        ccSyncedAt: ccSyncedAt ?? this.ccSyncedAt,
      );
}

class SharedPlaylist {
  const SharedPlaylist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final List<SharedPlaylistItem> items;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory SharedPlaylist.fromJson(Map<String, dynamic> j) => SharedPlaylist(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '플레이리스트',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        items: (j['items'] as List? ?? [])
            .map((e) => SharedPlaylistItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  SharedPlaylist copyWith({
    String? name,
    List<SharedPlaylistItem>? items,
  }) =>
      SharedPlaylist(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        items: items ?? this.items,
      );
}

class SharedPlaylistStore {
  SharedPlaylistStore._();

  static const _boxName = 'isle_shared_playlists';
  static const _key = 'playlists_v1';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('SharedPlaylistStore not open');
    return b;
  }

  static List<SharedPlaylist> loadAll() {
    final raw = box.get(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => SharedPlaylist.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<SharedPlaylist> playlists) async {
    await box.put(_key, jsonEncode(playlists.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static Future<SharedPlaylist> create(String name) async {
    final list = loadAll();
    final p = SharedPlaylist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      createdAt: DateTime.now(),
      items: const [],
    );
    list.insert(0, p);
    await saveAll(list);
    return p;
  }

  static Future<void> upsert(SharedPlaylist playlist) async {
    final list = loadAll();
    final idx = list.indexWhere((e) => e.id == playlist.id);
    if (idx >= 0) {
      list[idx] = playlist;
    } else {
      list.insert(0, playlist);
    }
    await saveAll(list);
  }

  /// CC·기사화 큐 — 공유 탭에서 Watch Later / 플레이리스트 URL을 넣는 기본 목록
  static const isleQueuePlaylistId = 'isle_cc_queue_v1';

  static Future<SharedPlaylist> ensureIsleQueue() async {
    final list = loadAll();
    final idx = list.indexWhere((e) => e.id == isleQueuePlaylistId);
    if (idx >= 0) return list[idx];
    final q = SharedPlaylist(
      id: isleQueuePlaylistId,
      name: 'Isle 큐',
      createdAt: DateTime.now(),
      items: const [],
    );
    list.insert(0, q);
    await saveAll(list);
    return q;
  }

  static SharedPlaylist? findById(String id) {
    try {
      return loadAll().firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> addItem({
    required String playlistId,
    required SharedPlaylistItem item,
  }) async {
    final list = loadAll();
    final idx = list.indexWhere((e) => e.id == playlistId);
    if (idx < 0) return false;
    final p = list[idx];
    if (p.items.any((x) => x.url == item.url)) return false;
    list[idx] = p.copyWith(items: [...p.items, item]);
    await saveAll(list);
    return true;
  }
}
