import 'package:hive_flutter/hive_flutter.dart';

import '../library/usage_day.dart';

/// 무료 MVP — 하루 AI 요약 횟수 (기본 5회, BM 훅)
class YoutubeFocusSummaryQuotaStore {
  YoutubeFocusSummaryQuotaStore._();

  static const freeDailyLimit = 5;

  static Box<String> get _box => Hive.box<String>('isle_cache');

  static String get _dayKey => UsageDay.key();

  static String _countKey(String day) => 'youtube_focus_summary_count_$day';

  static int get todayCount {
    final raw = _box.get(_countKey(_dayKey));
    return int.tryParse(raw ?? '') ?? 0;
  }

  static int get remaining => (freeDailyLimit - todayCount).clamp(0, freeDailyLimit);

  static bool get canRequestSummary => todayCount < freeDailyLimit;

  static Future<void> recordUse() async {
    await _box.put(_countKey(_dayKey), '${todayCount + 1}');
  }
}
