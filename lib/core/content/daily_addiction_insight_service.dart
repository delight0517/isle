import 'dart:convert';

import 'package:flutter/services.dart';

/// 미디어·SNS 과사용 경각심 — 날짜 기반 로컬 순환 콘텐츠 한 조각.
class AddictionInsight {
  const AddictionInsight({required this.id, required this.text});

  final String id;
  final String text;
}

/// 날짜 결정적(day-of-year % length) 순환 — RNG·API 없이 매일 다른 항목을 보여준다.
/// 같은 날 여러 번 호출해도 같은 항목, 날짜가 바뀌면 다음 항목.
class DailyAddictionInsightService {
  DailyAddictionInsightService._();

  static const _assetPath = 'assets/content/addiction_insights_ko.json';
  static List<AddictionInsight>? _cache;

  static Future<void> _ensureLoaded() async {
    if (_cache != null) return;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final list = decoded['entries'] as List? ?? const [];
      _cache = list
          .map((e) => AddictionInsight(
                id: (e as Map)['id'] as String? ?? '',
                text: e['text'] as String? ?? '',
              ))
          .where((e) => e.text.isNotEmpty)
          .toList();
    } catch (_) {
      _cache = const [];
    }
  }

  /// [now] 를 주입하면 테스트에서 날짜를 고정할 수 있다(기본값은 실제 오늘).
  static Future<AddictionInsight?> todayInsight({DateTime? now}) async {
    await _ensureLoaded();
    final entries = _cache;
    if (entries == null || entries.isEmpty) return null;
    final date = now ?? DateTime.now();
    final ordinal = date.year * 366 + _dayOfYear(date);
    return entries[ordinal % entries.length];
  }

  static int _dayOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return date.difference(startOfYear).inDays + 1;
  }
}
