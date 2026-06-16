import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_local_data_sync.dart';

/// 인스타 구독(@) 목록 — 관심 없음·Isle에서 숨김 (언팔로우는 인스타 앱에서)
class InstagramFollowingStore {
  InstagramFollowingStore._();

  static const _boxName = 'isle_instagram_following';
  static const _listKey = 'handles_v1';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('InstagramFollowingStore not open');
    }
    return b;
  }

  static List<InstagramFollowEntry> loadAll() {
    final raw = box.get(_listKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => InstagramFollowEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<InstagramFollowEntry> visible() =>
      loadAll().where((e) => !e.hidden).toList();

  static Future<void> saveAll(List<InstagramFollowEntry> entries) async {
    await box.put(_listKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static Future<void> addHandle(String handle) async {
    final h = handle.replaceAll('@', '').trim().toLowerCase();
    if (h.isEmpty) return;
    final list = loadAll();
    if (list.any((e) => e.handle == h)) return;
    list.add(InstagramFollowEntry(handle: h));
    await saveAll(list);
  }

  static Future<void> setHidden(String handle, bool hidden) async {
    final h = handle.toLowerCase();
    final list = loadAll();
    final i = list.indexWhere((e) => e.handle == h);
    if (i < 0) return;
    list[i] = list[i].copyWith(hidden: hidden);
    await saveAll(list);
  }

  static Future<void> remove(String handle) async {
    final h = handle.toLowerCase();
    await saveAll(loadAll().where((e) => e.handle != h).toList());
  }
}

class InstagramFollowEntry {
  const InstagramFollowEntry({
    required this.handle,
    this.displayName = '',
    this.hidden = false,
    this.addedAt,
  });

  final String handle;
  final String displayName;
  final bool hidden;
  final DateTime? addedAt;

  Map<String, dynamic> toJson() => {
        'handle': handle,
        'display_name': displayName,
        'hidden': hidden,
        'added_at': (addedAt ?? DateTime.now()).toIso8601String(),
      };

  factory InstagramFollowEntry.fromJson(Map<String, dynamic> j) => InstagramFollowEntry(
        handle: (j['handle'] as String? ?? '').toLowerCase(),
        displayName: j['display_name'] as String? ?? '',
        hidden: j['hidden'] == true,
        addedAt: DateTime.tryParse(j['added_at'] as String? ?? ''),
      );

  InstagramFollowEntry copyWith({bool? hidden, String? displayName}) => InstagramFollowEntry(
        handle: handle,
        displayName: displayName ?? this.displayName,
        hidden: hidden ?? this.hidden,
        addedAt: addedAt,
      );
}
