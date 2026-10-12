import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

enum SafeBrowserHistoryKind { opened, blocked }

class SafeBrowserHistoryEntry {
  const SafeBrowserHistoryEntry({
    required this.url,
    required this.kind,
    required this.atMs,
    this.note,
  });

  final String url;
  final SafeBrowserHistoryKind kind;
  final int atMs;
  final String? note;

  Map<String, dynamic> toJson() => {
        'url': url,
        'kind': kind.name,
        'atMs': atMs,
        if (note != null) 'note': note,
      };

  factory SafeBrowserHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SafeBrowserHistoryEntry(
      url: json['url'] as String? ?? '',
      kind: SafeBrowserHistoryKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => SafeBrowserHistoryKind.opened,
      ),
      atMs: json['atMs'] as int? ?? 0,
      note: json['note'] as String?,
    );
  }
}

/// Safe Browser — 최근 열기·차단 기록 (최대 80건)
class SafeBrowserHistoryStore {
  SafeBrowserHistoryStore._();

  static const _boxName = 'isle_safe_browser_history';
  static const _keyItems = 'items_v1';
  static const _maxItems = 80;

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    _box ??= await Hive.openBox<String>(_boxName);
  }

  static List<SafeBrowserHistoryEntry> loadAll() {
    final box = _box;
    if (box == null) return [];
    final raw = box.get(_keyItems);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SafeBrowserHistoryEntry.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _append(SafeBrowserHistoryEntry entry) async {
    await ensureOpen();
    final items = loadAll()..insert(0, entry);
    if (items.length > _maxItems) {
      items.removeRange(_maxItems, items.length);
    }
    await _box!.put(
      _keyItems,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> recordOpened(String url) =>
      _append(SafeBrowserHistoryEntry(
        url: url,
        kind: SafeBrowserHistoryKind.opened,
        atMs: DateTime.now().millisecondsSinceEpoch,
      ));

  static Future<void> recordBlocked(String url, String note) =>
      _append(SafeBrowserHistoryEntry(
        url: url,
        kind: SafeBrowserHistoryKind.blocked,
        atMs: DateTime.now().millisecondsSinceEpoch,
        note: note,
      ));
}
