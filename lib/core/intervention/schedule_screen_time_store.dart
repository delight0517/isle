import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_local_data_sync.dart';
import 'screen_time_persistence_service.dart';

/// 스케줄(×앱 bundle)별 Screen Time `FamilyActivitySelection` (base64) — App Group과 동기.
///
/// 키 스킴: `bundleId`가 없으면 스케줄 전체 통짜 선택(legacy·Android CSV 경로),
/// 있으면 그 스케줄 안 특정 앱(bundle) 전용 선택 — 카카오톡 체크박스를 꺼도
/// 실제 쉴드엔 반영 안 되던 버그(2026-07-06)의 근본 수정: 앱별로 분리 저장해야
/// 체크박스 하나가 실제로 그 앱 하나만 제어할 수 있다.
class ScheduleScreenTimeStore {
  ScheduleScreenTimeStore._();

  static const _boxName = 'isle_schedule_screen_time';
  static const _prefix = 'sel_';
  static const _bundleSep = '__';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('ScheduleScreenTimeStore not open');
    }
    return b;
  }

  static String _key(String scheduleId, String? bundleId) {
    if (bundleId == null || bundleId.isEmpty) return '$_prefix$scheduleId';
    return '$_prefix$scheduleId$_bundleSep$bundleId';
  }

  static String? encodedFor(String scheduleId, {String? bundleId}) {
    final raw = box.get(_key(scheduleId, bundleId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map['encoded'] as String?;
    } catch (_) {
      return null;
    }
  }

  static int appCountFor(String scheduleId, {String? bundleId}) {
    final raw = box.get(_key(scheduleId, bundleId));
    if (raw == null) return 0;
    try {
      return (jsonDecode(raw) as Map)['applicationCount'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static int categoryCountFor(String scheduleId, {String? bundleId}) {
    final raw = box.get(_key(scheduleId, bundleId));
    if (raw == null) return 0;
    try {
      return (jsonDecode(raw) as Map)['categoryCount'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 이 스케줄에 저장된 bundle 전용 선택들의 bundleId 목록(legacy 통짜 키는 제외).
  static List<String> bundleIdsWithSelection(String scheduleId) {
    final schedulePrefix = '$_prefix$scheduleId$_bundleSep';
    return box.keys
        .whereType<String>()
        .where((k) => k.startsWith(schedulePrefix))
        .map((k) => k.substring(schedulePrefix.length))
        .toList();
  }

  /// 이 스케줄의 모든 bundle 선택을 `{bundleId: encoded}`로 모아 반환.
  static Map<String, String> allEncodedForSchedule(String scheduleId) {
    final out = <String, String>{};
    for (final bundleId in bundleIdsWithSelection(scheduleId)) {
      final e = encodedFor(scheduleId, bundleId: bundleId);
      if (e != null) out[bundleId] = e;
    }
    return out;
  }

  /// 이 스케줄에 실제로 앱·카테고리가 하나라도 골라져 있는지(legacy 통짜 키 +
  /// 모든 bundle 키 통틀어) — "체크박스는 켜져 있는데 Screen Time에서 아무
  /// 앱도 고른 적 없어서 실제로는 아무것도 안 막는" 상태와, "진짜로 뭔가
  /// 막고 있어서 지금 빼면 안 되는" 상태를 구분하는 데 쓴다(2026-07-20,
  /// 앱 미선택인데 "차단됨"으로 표시되며 스케줄 락까지 걸리던 버그 수정).
  static bool hasAnySelection(String scheduleId) {
    if (appCountFor(scheduleId) > 0 || categoryCountFor(scheduleId) > 0) {
      return true;
    }
    for (final bundleId in bundleIdsWithSelection(scheduleId)) {
      if (appCountFor(scheduleId, bundleId: bundleId) > 0 ||
          categoryCountFor(scheduleId, bundleId: bundleId) > 0) {
        return true;
      }
    }
    return false;
  }

  static Future<void> savePick({
    required String scheduleId,
    String? bundleId,
    required String encoded,
    required int applicationCount,
    required int categoryCount,
  }) async {
    await box.put(
      _key(scheduleId, bundleId),
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

  /// 스케줄의 legacy 통짜 키 + 모든 bundle별 키를 전부 삭제.
  static Future<void> clear(String scheduleId) async {
    final legacyKey = _key(scheduleId, null);
    final bundlePrefix = '$_prefix$scheduleId$_bundleSep';
    final keysToDelete = box.keys
        .whereType<String>()
        .where((k) => k == legacyKey || k.startsWith(bundlePrefix))
        .toList();
    for (final k in keysToDelete) {
      await box.delete(k);
    }
    isleNotifyLocalDataChanged();
  }

  /// 특정 bundle 하나의 선택만 삭제(체크박스 OFF 시 그 앱만 실제로 해제).
  static Future<void> clearBundle(String scheduleId, String bundleId) async {
    await box.delete(_key(scheduleId, bundleId));
    isleNotifyLocalDataChanged();
  }

  static const _migratedFlagKey = '__migrated_per_bundle_v1';

  /// bundle별 저장 마이그레이션(2026-07-06)이 이미 끝났는지 — 오케스트레이션은
  /// 카탈로그를 아는 `ScheduleAppTargetsService`가 하고, 이 store는 sentinel만 보관.
  static bool get migratedToPerBundle => box.get(_migratedFlagKey) == 'yes';

  static Future<void> markMigratedToPerBundle() async {
    await box.put(_migratedFlagKey, 'yes');
  }
}
