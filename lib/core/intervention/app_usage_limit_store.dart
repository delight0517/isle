import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'models/app_usage_limit_rule.dart';

class AppUsageLimitStore {
  AppUsageLimitStore._();

  static const _boxName = 'isle_app_usage_limits';
  static const _rulesKey = 'rules_json';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('AppUsageLimitStore.ensureOpen() first');
    }
    return b;
  }

  static List<AppUsageLimitRule> loadRules() {
    final raw = box.get(_rulesKey);
    if (raw == null || raw.isEmpty) return _defaultRules();
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => AppUsageLimitRule.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return _defaultRules();
    }
  }

  static Future<void> saveRules(List<AppUsageLimitRule> rules) async {
    final encoded = jsonEncode(rules.map((e) => e.toJson()).toList());
    await box.put(_rulesKey, encoded);
  }

  static List<AppUsageLimitRule> _defaultRules() => [
        const AppUsageLimitRule(
          id: 'instagram',
          label: 'Instagram',
          minutesPerWindow: 20,
          enabled: false,
          presetId: 'instagram',
          androidPackageName: 'com.instagram.android',
        ),
      ];

  static AppUsageLimitRule? ruleById(String id) {
    for (final r in loadRules()) {
      if (r.id == id) return r;
    }
    return null;
  }
}
