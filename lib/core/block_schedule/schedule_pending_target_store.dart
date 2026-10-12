import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'models/pending_schedule_target_edit.dart';

const _boxName = 'isle_schedule_pending_targets';
const _listKey = 'pending_v1';

class SchedulePendingTargetStore {
  SchedulePendingTargetStore._();

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('SchedulePendingTargetStore.ensureOpen() first');
    }
    return b;
  }

  static List<PendingScheduleTargetEdit> loadAll() {
    final raw = box.get(_listKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) =>
              PendingScheduleTargetEdit.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((p) => p.scheduleId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<PendingScheduleTargetEdit> list) async {
    await box.put(_listKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static List<PendingScheduleTargetEdit> loadForSchedule(String scheduleId) {
    return loadAll().where((p) => p.scheduleId == scheduleId).toList();
  }

  static PendingScheduleTargetEdit? findEntry(String scheduleId, String targetId) {
    for (final p in loadAll()) {
      if (p.scheduleId == scheduleId &&
          p.kind == PendingScheduleTargetKind.entry &&
          p.targetId == targetId) {
        return p;
      }
    }
    return null;
  }

  static PendingScheduleTargetEdit? findIosPickSync(String scheduleId) {
    for (final p in loadAll()) {
      if (p.scheduleId == scheduleId && p.kind == PendingScheduleTargetKind.iosPickSync) {
        return p;
      }
    }
    return null;
  }

  static Future<void> upsert(PendingScheduleTargetEdit pending) async {
    final list = loadAll()
      ..removeWhere((p) {
        if (p.scheduleId != pending.scheduleId) return false;
        if (pending.kind == PendingScheduleTargetKind.iosPickSync) {
          return p.kind == PendingScheduleTargetKind.iosPickSync;
        }
        return p.kind == PendingScheduleTargetKind.entry &&
            p.targetId == pending.targetId;
      })
      ..add(pending);
    await saveAll(list);
  }

  static Future<void> cancelEntry(String scheduleId, String targetId) async {
    final list = loadAll()
      ..removeWhere((p) =>
          p.scheduleId == scheduleId &&
          p.kind == PendingScheduleTargetKind.entry &&
          p.targetId == targetId);
    await saveAll(list);
  }

  static Future<void> cancelIosPickSync(String scheduleId) async {
    final list = loadAll()
      ..removeWhere((p) =>
          p.scheduleId == scheduleId && p.kind == PendingScheduleTargetKind.iosPickSync);
    await saveAll(list);
  }

  static Future<void> removeApplied(List<PendingScheduleTargetEdit> applied) async {
    if (applied.isEmpty) return;
    final keys = applied
        .map((p) => '${p.scheduleId}|${p.kind.name}|${p.targetId}')
        .toSet();
    final list = loadAll()
      ..removeWhere((p) => keys.contains('${p.scheduleId}|${p.kind.name}|${p.targetId}'));
    await saveAll(list);
  }
}
