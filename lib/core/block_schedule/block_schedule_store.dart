import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_user_defaults.dart';
import '../youtube/models/youtube_schedule_rule.dart';
import '../services/isle_local_data_sync.dart';
import 'models/block_schedule.dart';
import 'models/schedule_slot.dart';
import 'schedule_constants.dart';
import 'schedule_lock_service.dart';
import 'schedule_persist_guard.dart';

const _boxName = 'isle_block_schedules';
const _schedulesKey = 'schedules_v2';
const _legacyBox = 'isle_youtube_schedule';
const _legacyKey = 'rules_v1';

class BlockScheduleStore {
  BlockScheduleStore._();

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
    await _migrateLegacyIfNeeded();
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('BlockScheduleStore not open');
    return b;
  }

  static bool get masterEnabled => IsleUserDefaults.youtubeScheduleLockEnabled;

  static List<BlockSchedule> loadAll() {
    final raw = box.get(_schedulesKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => BlockSchedule.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<BlockSchedule> list) async {
    await box.put(_schedulesKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    isleNotifyLocalDataChanged();
  }

  static Future<BlockSchedule> create({
    required String name,
    List<ScheduleSlot>? slots,
    bool locked = false,
    int lockCooldownMinutes = 30,
  }) async {
    final list = loadAll();
    final s = BlockSchedule(
      id: 'sch_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      locked: locked,
      lockCooldownMinutes: lockCooldownMinutes.clamp(ScheduleConstants.minCooldownMinutes, 24 * 60),
      slots: slots ?? [],
    );
    list.add(s);
    await saveAll(list);
    return s;
  }

  static Future<void> upsert(BlockSchedule schedule) async {
    final list = loadAll();
    final idx = list.indexWhere((s) => s.id == schedule.id);
    final existing = idx >= 0 ? list[idx] : null;
    final sanitized = SchedulePersistGuard.sanitizeUpsert(
      existing: existing,
      incoming: schedule,
    );
    if (idx >= 0) {
      list[idx] = sanitized;
    } else {
      list.add(sanitized);
    }
    await saveAll(list);
  }

  /// 타임락 중 삭제는 false (UI·AI 우회 방지)
  static Future<bool> delete(String id) async {
    final list = loadAll();
    final existing = list.where((s) => s.id == id).firstOrNull;
    if (existing != null && !SchedulePersistGuard.canDelete(existing)) {
      return false;
    }
    list.removeWhere((s) => s.id == id);
    await saveAll(list);
    return true;
  }

  static Future<void> _migrateLegacyIfNeeded() async {
    if (box.get('legacy_migrated') == 'yes') return;
    try {
      final legacyBox = await Hive.openBox<String>(_legacyBox);
      final raw = legacyBox.get(_legacyKey);
      if (raw != null) {
        final rules = (jsonDecode(raw) as List)
            .map((e) => YoutubeScheduleRule.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        final out = loadAll();
        for (final r in rules) {
          final slots = <ScheduleSlot>[];
          for (final wd in r.weekdays) {
            slots.add(
              ScheduleSlot(
                day: wd - 1,
                startMinute: r.startMinutes,
                endMinute: r.endMinutes,
              ),
            );
          }
          out.add(
            BlockSchedule(
              id: r.id,
              name: r.label(),
              enabled: r.enabled,
              slots: slots,
            ),
          );
        }
        if (out.isNotEmpty) await saveAll(out);
      }
    } catch (_) {}
    await box.put('legacy_migrated', 'yes');
  }
}

final blockSchedulesProvider =
    StateNotifierProvider<BlockSchedulesNotifier, List<BlockSchedule>>((ref) {
  return BlockSchedulesNotifier();
});

class BlockSchedulesNotifier extends StateNotifier<List<BlockSchedule>> {
  BlockSchedulesNotifier() : super(BlockScheduleStore.loadAll());

  Future<void> reload() async {
    await ScheduleLockService.finalizeExpiredLocks();
    state = BlockScheduleStore.loadAll();
  }

  Future<BlockSchedule> createDefault(String name) async {
    final s = await BlockScheduleStore.create(name: name);
    state = BlockScheduleStore.loadAll();
    return s;
  }
}
