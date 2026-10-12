import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Safe Browser — 도메인 임시 허용 (15분·오늘만)
class SafeBrowserTemporaryAllowStore {
  SafeBrowserTemporaryAllowStore._();

  static const _boxName = 'isle_safe_browser_allow';
  static const _keyHosts = 'hosts_v1';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    _box ??= await Hive.openBox<String>(_boxName);
  }

  static Map<String, int> _load() {
    final box = _box;
    if (box == null) return {};
    final raw = box.get(_keyHosts);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> _save(Map<String, int> hosts) async {
    await ensureOpen();
    final now = DateTime.now().millisecondsSinceEpoch;
    hosts.removeWhere((_, expiresMs) => expiresMs <= now);
    await _box!.put(_keyHosts, jsonEncode(hosts));
  }

  static String _normHost(String host) {
    return host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  }

  static bool isAllowed(String? host) {
    if (host == null || host.isEmpty) return false;
    final h = _normHost(host);
    final map = _load();
    final expires = map[h];
    if (expires == null) return false;
    if (expires <= DateTime.now().millisecondsSinceEpoch) {
      return false;
    }
    return true;
  }

  static Future<void> grantHost(String host, Duration duration) async {
    final h = _normHost(host);
    if (h.isEmpty) return;
    final map = _load();
    final expires = DateTime.now().add(duration).millisecondsSinceEpoch;
    map[h] = expires;
    await _save(map);
  }

  static Future<void> grantUntilEndOfDay(String host) async {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final diff = end.difference(now);
    await grantHost(host, diff.isNegative ? const Duration(hours: 1) : diff);
  }

  static List<({String host, DateTime expiresAt})> listActive() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _load().entries
        .where((e) => e.value > now)
        .map(
          (e) => (
            host: e.key,
            expiresAt: DateTime.fromMillisecondsSinceEpoch(e.value),
          ),
        )
        .toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
  }
}
