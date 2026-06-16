import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_local_data_sync.dart';

const _boxName = 'isle_brunch_blocked';
const _listKey = 'authors_v1';

class BrunchBlockedAuthor {
  const BrunchBlockedAuthor({
    required this.handle,
    required this.displayName,
    required this.blockedAt,
  });

  final String handle;
  final String displayName;
  final DateTime blockedAt;

  factory BrunchBlockedAuthor.fromJson(Map<String, dynamic> j) => BrunchBlockedAuthor(
        handle: j['handle'] as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        blockedAt: DateTime.tryParse(j['blocked_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'handle': handle,
        'display_name': displayName,
        'blocked_at': blockedAt.toIso8601String(),
      };

  bool matches(String haystack) {
    final h = handle.toLowerCase();
    final n = displayName.toLowerCase();
    final t = haystack.toLowerCase();
    if (h.isNotEmpty && (t.contains(h) || t.contains('@$h'))) return true;
    if (n.isNotEmpty && t.contains(n)) return true;
    return false;
  }
}

class BrunchBlockedAuthorStore {
  BrunchBlockedAuthorStore._();

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static List<BrunchBlockedAuthor> loadAll() {
    final raw = _box?.get(_listKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => BrunchBlockedAuthor.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<BrunchBlockedAuthor> list) async {
    await box.put(_listKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('BrunchBlockedAuthorStore not open');
    return b;
  }
}

final brunchBlockedAuthorsProvider =
    StateNotifierProvider<BrunchBlockedAuthorsNotifier, List<BrunchBlockedAuthor>>((ref) {
  return BrunchBlockedAuthorsNotifier();
});

class BrunchBlockedAuthorsNotifier extends StateNotifier<List<BrunchBlockedAuthor>> {
  BrunchBlockedAuthorsNotifier() : super(BrunchBlockedAuthorStore.loadAll());

  Future<void> reload() async {
    state = BrunchBlockedAuthorStore.loadAll();
  }

  Future<void> block({required String handle, required String displayName}) async {
    final h = handle.replaceAll('@', '').trim().toLowerCase();
    final name = displayName.trim();
    if (h.isEmpty && name.isEmpty) return;
    final list = List<BrunchBlockedAuthor>.from(state);
    list.removeWhere((e) => e.handle == h);
    list.add(BrunchBlockedAuthor(
      handle: h,
      displayName: name.isNotEmpty ? name : h,
      blockedAt: DateTime.now(),
    ));
    await BrunchBlockedAuthorStore.saveAll(list);
    state = list;
  }

  Future<void> unblock(String handle) async {
    final list = state.where((e) => e.handle != handle).toList();
    await BrunchBlockedAuthorStore.saveAll(list);
    state = list;
  }
}
