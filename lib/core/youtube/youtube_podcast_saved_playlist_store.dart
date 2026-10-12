import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_local_data_sync.dart';

/// Isle에만 있는 **비공식** 재생목록 — YT Music 미등록 영상·링크·공개 PL URL 혼합 가능
class YoutubePodcastSavedPlaylist {
  const YoutubePodcastSavedPlaylist({
    required this.id,
    required this.name,
    required this.links,
    required this.createdAt,
  });

  final String id;
  final String name;
  /// `watch?v=` · `playlist?list=` · `youtu.be/` 등
  final List<String> links;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'links': links,
        'created_at': createdAt.toIso8601String(),
      };

  factory YoutubePodcastSavedPlaylist.fromJson(Map<String, dynamic> j) =>
      YoutubePodcastSavedPlaylist(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '재생목록',
        links: (j['links'] as List? ?? []).map((e) => e.toString()).toList(),
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  YoutubePodcastSavedPlaylist copyWith({
    String? name,
    List<String>? links,
  }) =>
      YoutubePodcastSavedPlaylist(
        id: id,
        name: name ?? this.name,
        links: links ?? this.links,
        createdAt: createdAt,
      );
}

class YoutubePodcastSavedPlaylistStore {
  YoutubePodcastSavedPlaylistStore._();

  static const _boxName = 'isle_youtube_podcast_playlists';
  static const _key = 'saved_v1';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('YoutubePodcastSavedPlaylistStore not open');
    }
    return b;
  }

  static bool get isOpen => _box?.isOpen ?? false;

  static List<YoutubePodcastSavedPlaylist> loadAll() {
    final raw = box.get(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => YoutubePodcastSavedPlaylist.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<YoutubePodcastSavedPlaylist> list) async {
    await box.put(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static Future<YoutubePodcastSavedPlaylist> create(String name) async {
    final list = loadAll();
    final p = YoutubePodcastSavedPlaylist(
      id: 'ytpl_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? '내 재생목록' : name.trim(),
      links: const [],
      createdAt: DateTime.now(),
    );
    list.insert(0, p);
    await saveAll(list);
    return p;
  }

  static Future<bool> addLink({
    required String playlistId,
    required String url,
  }) async {
    final t = url.trim();
    if (t.isEmpty) return false;
    final list = loadAll();
    final idx = list.indexWhere((e) => e.id == playlistId);
    if (idx < 0) return false;
    final p = list[idx];
    if (p.links.any((l) => l.trim() == t)) return false;
    list[idx] = p.copyWith(links: [...p.links, t]);
    await saveAll(list);
    return true;
  }

  static Future<void> removeLink({
    required String playlistId,
    required String url,
  }) async {
    final list = loadAll();
    final idx = list.indexWhere((e) => e.id == playlistId);
    if (idx < 0) return;
    final p = list[idx];
    list[idx] = p.copyWith(links: p.links.where((l) => l != url).toList());
    await saveAll(list);
  }

  static Future<void> deletePlaylist(String id) async {
    final list = loadAll()..removeWhere((e) => e.id == id);
    await saveAll(list);
  }

  static Future<void> rename(String id, String name) async {
    final list = loadAll();
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(name: name.trim());
    await saveAll(list);
  }
}
