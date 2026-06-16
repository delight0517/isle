import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'schedule_rule.dart';
import 'schedule_rule_kind.dart';

class ScheduleRuleStore {
  ScheduleRuleStore._();

  static const _boxName = 'isle_schedule_rules';
  static const _listKey = 'rules_v1';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get _b {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('ScheduleRuleStore.ensureOpen() first');
    return b;
  }

  static List<ScheduleRule> loadAll() {
    final raw = _b.get(_listKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => ScheduleRule.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((r) => r.id.isNotEmpty && r.scheduleId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<ScheduleRule> loadForSchedule(String scheduleId) =>
      loadAll().where((r) => r.scheduleId == scheduleId).toList()
        ..sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));

  static Future<void> saveAll(List<ScheduleRule> rules) async {
    await _b.put(_listKey, jsonEncode(rules.map((e) => e.toJson()).toList()));
  }

  static Future<void> upsert(ScheduleRule rule) async {
    final all = loadAll();
    final idx = all.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      all[idx] = rule;
    } else {
      all.add(rule);
    }
    await saveAll(all);
  }

  static Future<void> delete(String ruleId) async {
    await saveAll(loadAll().where((r) => r.id != ruleId).toList());
  }

  static Future<void> deleteForSchedule(String scheduleId) async {
    await saveAll(loadAll().where((r) => r.scheduleId != scheduleId).toList());
  }

  static bool hasDuplicate({
    required String scheduleId,
    required ScheduleRuleKind kind,
    required String pattern,
  }) {
    final p = pattern.toLowerCase().trim();
    return loadForSchedule(scheduleId).any(
      (r) => r.kind == kind && r.pattern == p,
    );
  }
}
