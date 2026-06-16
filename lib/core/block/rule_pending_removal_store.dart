import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'models/pending_rule_removal.dart';

const _boxName = 'isle_rule_pending_removals';
const _listKey = 'pending_v1';

class RulePendingRemovalStore {
  RulePendingRemovalStore._();

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('RulePendingRemovalStore.ensureOpen() first');
    }
    return b;
  }

  static List<PendingRuleRemoval> loadAll() {
    final raw = box.get(_listKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PendingRuleRemoval.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((p) => p.key.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<PendingRuleRemoval> list) async {
    await box.put(_listKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static PendingRuleRemoval? find(PendingRuleRemovalKind kind, String key) {
    final k = key.trim();
    if (k.isEmpty) return null;
    for (final p in loadAll()) {
      if (p.kind == kind && p.key == k) return p;
    }
    return null;
  }

  static Future<void> cancelKind(PendingRuleRemovalKind kind, String key) async {
    final k = kind == PendingRuleRemovalKind.keyword ? key.trim().toLowerCase() : key.trim();
    if (k.isEmpty) return;
    final list = loadAll()..removeWhere((p) => p.kind == kind && p.key == k);
    await saveAll(list);
  }
}
