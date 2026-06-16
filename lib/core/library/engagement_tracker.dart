import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// 화면·콘텐츠 상호작용 로컬 기록 → 피드·검색 가중치 (서버 동기화 없음)
class EngagementTracker {
  EngagementTracker._();

  static const _boxName = 'isle_engagement';
  static const _opensKey = 'content_opens_v1';
  static const _screensKey = 'screen_seconds_v1';
  static const _dailyKey = 'daily_seconds_v1';
  static const dailyRetentionDays = 30;

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('EngagementTracker not initialized');
    return b;
  }

  static Map<String, int> _loadOpens() {
    final raw = box.get(_opensKey);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Map<String, int> _loadScreens() {
    final raw = box.get(_screensKey);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> recordContentOpen(String url, {String sourceType = 'article'}) async {
    final key = '$sourceType::$url';
    final opens = _loadOpens();
    opens[key] = (opens[key] ?? 0) + 1;
    await box.put(_opensKey, jsonEncode(opens));
  }

  static Future<void> recordScreen(String screenId, {int seconds = 5}) async {
    if (screenId.isEmpty) return;
    final screens = _loadScreens();
    screens[screenId] = (screens[screenId] ?? 0) + seconds;
    await box.put(_screensKey, jsonEncode(screens));
    // 일별 버킷 누적 — 그래프·추천 데이터 소스
    await _recordDaily(screenId, seconds);
  }

  /// `YYYY-MM-DD::platformOrScreen` 키로 일별 누적
  static Future<void> _recordDaily(String screenId, int seconds) async {
    final day = _todayKey();
    final daily = _loadDaily();
    final key = '$day::$screenId';
    daily[key] = (daily[key] ?? 0) + seconds;
    _pruneOldDays(daily);
    await box.put(_dailyKey, jsonEncode(daily));
  }

  static String _todayKey({DateTime? at}) {
    final d = (at ?? DateTime.now()).toLocal();
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }

  static void _pruneOldDays(Map<String, int> daily) {
    final cutoff = DateTime.now().subtract(Duration(days: dailyRetentionDays));
    daily.removeWhere((key, _) {
      final parts = key.split('::');
      if (parts.length < 2) return true;
      final dayParts = parts[0].split('-');
      if (dayParts.length != 3) return true;
      final y = int.tryParse(dayParts[0]);
      final m = int.tryParse(dayParts[1]);
      final d = int.tryParse(dayParts[2]);
      if (y == null || m == null || d == null) return true;
      return DateTime(y, m, d).isBefore(cutoff);
    });
  }

  static Map<String, int> _loadDaily() {
    final raw = box.get(_dailyKey);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  /// 최근 N일 × 플랫폼별 초. 결과: `{'2026-05-27': {'youtube': 1820, 'instagram': 600}, ...}`
  /// platforms 인자는 substring 매칭 — screenId가 그 문자열을 포함하면 합산.
  static Map<String, Map<String, int>> dailyByPlatform({
    required List<String> platforms,
    int days = 7,
  }) {
    final daily = _loadDaily();
    final out = <String, Map<String, int>>{};
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final dayKey = _todayKey(at: now.subtract(Duration(days: i)));
      out[dayKey] = {for (final p in platforms) p: 0};
    }
    for (final e in daily.entries) {
      final parts = e.key.split('::');
      if (parts.length < 2) continue;
      final day = parts[0];
      final id = parts.sublist(1).join('::').toLowerCase();
      if (!out.containsKey(day)) continue;
      for (final p in platforms) {
        if (id.contains(p)) {
          out[day]![p] = (out[day]![p] ?? 0) + e.value;
        }
      }
    }
    return out;
  }

  /// 오늘 플랫폼별 초
  static Map<String, int> todayByPlatform(List<String> platforms) {
    final all = dailyByPlatform(platforms: platforms, days: 1);
    return all.values.firstOrNull ?? {for (final p in platforms) p: 0};
  }

  /// URL별 0.0–0.35 부스트
  static double boostForUrl(String url) {
    final opens = _loadOpens();
    var max = 0;
    for (final e in opens.entries) {
      if (!e.key.contains(url)) continue;
      if (e.value > max) max = e.value;
    }
    return (max * 0.07).clamp(0.0, 0.35);
  }

  static double boostForSourceType(String sourceType) {
    final opens = _loadOpens();
    var sum = 0;
    for (final e in opens.entries) {
      if (e.key.startsWith('$sourceType::')) sum += e.value;
    }
    return (sum * 0.02).clamp(0.0, 0.25);
  }

  static List<String> topScreenIds({int limit = 5}) {
    final screens = _loadScreens();
    final sorted = screens.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// 플랫폼 통계 화면용 — screenId → 누적 초
  static Map<String, int> screenSecondsRaw() => Map<String, int>.from(_loadScreens());

  static Map<String, double> buildUrlBoostMap(Iterable<String> urls) {
    return {for (final u in urls) u: boostForUrl(u)};
  }
}
