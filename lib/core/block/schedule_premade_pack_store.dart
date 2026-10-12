import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'schedule_premade_pack_link.dart';

class SchedulePremadePackStore {
  SchedulePremadePackStore._();

  static const _boxName = 'isle_schedule_premade_packs';
  static const _listKey = 'links_v1';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get _b {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('SchedulePremadePackStore.ensureOpen() first');
    }
    return b;
  }

  static List<SchedulePremadePackLink> loadAll() {
    final raw = _b.get(_listKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => SchedulePremadePackLink.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((l) => l.scheduleId.isNotEmpty && l.packId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<SchedulePremadePackLink> linksForSchedule(String scheduleId) =>
      loadAll().where((l) => l.scheduleId == scheduleId).toList();

  static SchedulePremadePackLink? findLink({
    required String scheduleId,
    required String packId,
  }) {
    for (final l in loadAll()) {
      if (l.scheduleId == scheduleId && l.packId == packId) return l;
    }
    return null;
  }

  static bool isLinked({required String scheduleId, required String packId}) =>
      findLink(scheduleId: scheduleId, packId: packId) != null;

  static Future<void> saveAll(List<SchedulePremadePackLink> links) async {
    await _b.put(_listKey, jsonEncode(links.map((e) => e.toJson()).toList()));
  }

  static Future<void> upsert(SchedulePremadePackLink link) async {
    final all = loadAll();
    final idx = all.indexWhere(
      (l) => l.scheduleId == link.scheduleId && l.packId == link.packId,
    );
    if (idx >= 0) {
      all[idx] = link;
    } else {
      all.add(link);
    }
    await saveAll(all);
  }

  static Future<void> removeLink({
    required String scheduleId,
    required String packId,
  }) async {
    await saveAll(
      loadAll()
          .where((l) => !(l.scheduleId == scheduleId && l.packId == packId))
          .toList(),
    );
  }

  static Future<void> deleteLinksForSchedule(String scheduleId) async {
    await saveAll(loadAll().where((l) => l.scheduleId != scheduleId).toList());
  }
}
