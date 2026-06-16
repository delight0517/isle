import 'package:hive_flutter/hive_flutter.dart';

/// 몰입 모드 — 오늘 아낀 시간(초) 누적
class YoutubeFocusTimeStore {
  YoutubeFocusTimeStore._();

  static Box<String> get _box => Hive.box<String>('isle_cache');

  static String get _dayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static String _storageKey(String day) => 'youtube_focus_saved_sec_$day';

  static int get todaySavedSeconds {
    final raw = _box.get(_storageKey(_dayKey));
    return int.tryParse(raw ?? '') ?? 0;
  }

  static Future<void> addSavedSeconds(int seconds) async {
    if (seconds <= 0) return;
    final key = _storageKey(_dayKey);
    final next = todaySavedSeconds + seconds;
    await _box.put(key, next.toString());
  }

  /// UI용 — "45분" / "12분" / "30초"
  static String formatSavedLabel([int? seconds]) {
    final s = seconds ?? todaySavedSeconds;
    if (s <= 0) return '0분';
    if (s >= 3600) {
      final h = s ~/ 3600;
      final m = (s % 3600) ~/ 60;
      return m > 0 ? '$h시간 $m분' : '$h시간';
    }
    if (s >= 60) return '${s ~/ 60}분';
    return '$s초';
  }
}
