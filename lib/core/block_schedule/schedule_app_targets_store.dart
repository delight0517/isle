import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'models/schedule_app_target_entry.dart';
import 'schedule_app_target_catalog.dart';

/// 스케줄별 앱 타깃 설정
class ScheduleAppTargetsStore {
  ScheduleAppTargetsStore._();

  static const _boxName = 'isle_schedule_app_targets';
  static const _prefix = 'targets_';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('ScheduleAppTargetsStore.ensureOpen() first');
    return b;
  }

  /// 이 스케줄에 대해 한 번이라도 실제 저장이 있었는지 — [loadForSchedule]은
  /// 저장이 없어도 카탈로그 기본값(전부 blockInSlot:false)을 돌려주기 때문에
  /// "아직 저장 안 됨"과 "명시적으로 다 꺼짐"을 구분 못 한다.
  /// [ScheduleAppTargetsGuard]가 "잠긴 스케줄의 기존 값을 지킨다"를 최초
  /// 생성 시점(아직 아무것도 없어 지킬 게 없음)에 잘못 적용해 처음 차단
  /// 설정 자체가 카탈로그 기본값으로 되돌아가던 회귀를 막는 데 쓴다
  /// (Cage에서 먼저 발견·수정, 2026-07-11 이식).
  static bool hasSavedEntries(String scheduleId) {
    final raw = box.get('$_prefix$scheduleId');
    return raw != null && raw.isNotEmpty;
  }

  static List<ScheduleAppTargetEntry> loadForSchedule(String scheduleId) {
    final raw = box.get('$_prefix$scheduleId');
    if (raw == null || raw.isEmpty) return _defaults();
    try {
      final list = jsonDecode(raw) as List;
      final parsed = list
          .map((e) => ScheduleAppTargetEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((e) => e.targetId.isNotEmpty)
          .toList();
      return _mergeWithDefaults(parsed);
    } catch (_) {
      return _defaults();
    }
  }

  static Future<void> saveForSchedule(String scheduleId, List<ScheduleAppTargetEntry> entries) async {
    await box.put('$_prefix$scheduleId', jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  static ScheduleAppTargetEntry? entryFor(String scheduleId, String targetId) {
    for (final e in loadForSchedule(scheduleId)) {
      if (e.targetId == targetId) return e;
    }
    return null;
  }

  static List<ScheduleAppTargetEntry> defaultEntries() => ScheduleAppTargetCatalog.targets
      .map((d) => ScheduleAppTargetEntry(targetId: d.id))
      .toList();

  /// 저장 목록 + 카탈로그 신규 ID 병합 (UI·persist 공용)
  static List<ScheduleAppTargetEntry> mergeWithCatalog(List<ScheduleAppTargetEntry> saved) =>
      _mergeWithDefaults(saved);

  static List<ScheduleAppTargetEntry> _defaults() => defaultEntries();

  static List<ScheduleAppTargetEntry> _mergeWithDefaults(List<ScheduleAppTargetEntry> saved) {
    final byId = {for (final e in saved) e.targetId: e};
    return ScheduleAppTargetCatalog.targets.map((d) {
      return byId[d.id] ?? ScheduleAppTargetEntry(targetId: d.id);
    }).toList();
  }
}
