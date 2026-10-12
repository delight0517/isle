import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'models/pending_schedule_field_edit.dart';

const _boxName = 'isle_schedule_pending_fields';
const _listKey = 'pending_v1';

class SchedulePendingFieldStore {
  SchedulePendingFieldStore._();

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('SchedulePendingFieldStore.ensureOpen() first');
    }
    return b;
  }

  static List<PendingScheduleFieldEdit> loadAll() {
    final raw = box.get(_listKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PendingScheduleFieldEdit.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((p) => p.scheduleId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<PendingScheduleFieldEdit> list) async {
    await box.put(_listKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static PendingScheduleFieldEdit? findFor(String scheduleId) {
    for (final p in loadAll()) {
      if (p.scheduleId == scheduleId) return p;
    }
    return null;
  }

  /// 기존 대기 중인 항목이 있으면 필드 단위로 병합(다른 필드는 유지), 없으면 새로 추가
  static Future<void> upsertMerged(PendingScheduleFieldEdit pending) async {
    final list = loadAll();
    final idx = list.indexWhere((p) => p.scheduleId == pending.scheduleId);
    if (idx >= 0) {
      list[idx] = list[idx].mergedWith(pending);
    } else {
      list.add(pending);
    }
    await saveAll(list);
  }

  static Future<void> cancelFor(String scheduleId) async {
    final list = loadAll()..removeWhere((p) => p.scheduleId == scheduleId);
    await saveAll(list);
  }

  static Future<void> removeApplied(Iterable<String> scheduleIds) async {
    final ids = scheduleIds.toSet();
    if (ids.isEmpty) return;
    final list = loadAll()..removeWhere((p) => ids.contains(p.scheduleId));
    await saveAll(list);
  }
}
