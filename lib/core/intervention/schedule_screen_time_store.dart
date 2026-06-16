import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_local_data_sync.dart';
import 'screen_time_persistence_service.dart';

/// 스케줄별 Screen Time `FamilyActivitySelection` (base64) — App Group과 동기.
class ScheduleScreenTimeStore {
  ScheduleScreenTimeStore._();

  static const _boxName = 'isle_schedule_screen_time';
  static const _prefix = 'sel_';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('ScheduleScreenTimeStore not open');
    return b;
  }

  static String? encodedFor(String scheduleId) {
    final raw = box.get('$_prefix$scheduleId');
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map['encoded'] as String?;
    } catch (_) {
      return null;
    }
  }

  static int appCountFor(String scheduleId) {
    final raw = box.get('$_prefix$scheduleId');
    if (raw == null) return 0;
    try {
      return (jsonDecode(raw) as Map)['applicationCount'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static int categoryCountFor(String scheduleId) {
    final raw = box.get('$_prefix$scheduleId');
    if (raw == null) return 0;
    try {
      return (jsonDecode(raw) as Map)['categoryCount'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> savePick({
    required String scheduleId,
    required String encoded,
    required int applicationCount,
    required int categoryCount,
  }) async {
    await box.put(
      '$_prefix$scheduleId',
      jsonEncode({
        'encoded': encoded,
        'applicationCount': applicationCount,
        'categoryCount': categoryCount,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );
    isleNotifyLocalDataChanged();
    await ScreenTimePersistenceService.syncMirror();
  }

  static Future<void> clear(String scheduleId) async {
    await box.delete('$_prefix$scheduleId');
    isleNotifyLocalDataChanged();
  }
}
