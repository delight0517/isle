import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_user_defaults.dart';
import '../youtube/models/youtube_schedule_rule.dart';
import '../services/isle_local_data_sync.dart';
import 'models/block_schedule.dart';
import 'models/schedule_enforcement_mode.dart';
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

  static bool get isOpen => _box != null && _box!.isOpen;

  static bool get masterEnabled => IsleUserDefaults.youtubeScheduleLockEnabled;

  // loadAll()이 캐시 없이 매번 전체 스케줄 리스트를 JSON 디코드하는데, 웹뷰가
  // 열려있는 동안 1초마다 도는 워치 타이머(_recordScheduleBundleUsageSecond →
  // ScheduleActiveService.activeSchedulesNow)가 이걸 매초 최대 두 번 호출한다
  // — 스케줄이 많아질수록 브라우징(특히 인스타그램) 중 체감 렉으로 이어지던
  // 실사용 버그(2026-07-13 사용자 제보). 쓰기 경로가 saveAll() 하나뿐이라
  // 캐시 무효화가 안전하다 — saveAll() 호출 시에만 무효화한다.
  static List<BlockSchedule>? _cache;

  // 캐시 리스트 자체를 그대로 반환하면, 호출부의 "final list = loadAll();
  // list.add(x); await saveAll(list);" 같은 흔한 패턴이 saveAll() 호출 전에
  // 캐시를 직접 mutate해버려 그 사이 다른 loadAll() 호출이 아직 저장 안 된
  // 상태를 보게 될 수 있다 — 매번 얕은 복사본을 반환해 캐시 자체는 항상
  // saveAll()을 통해서만 바뀌게 한다.
  static List<BlockSchedule> loadAll() {
    final cached = _cache;
    if (cached != null) return List.of(cached);
    final raw = box.get(_schedulesKey);
    if (raw == null) {
      _cache = [];
      return [];
    }
    try {
      final parsed = (jsonDecode(raw) as List)
          .map((e) => BlockSchedule.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _cache = parsed;
      return List.of(parsed);
    } catch (_) {
      _cache = [];
      return [];
    }
  }

  static Future<void> saveAll(List<BlockSchedule> list) async {
    await box.put(_schedulesKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    _cache = List.of(list);
    isleNotifyLocalDataChanged();
  }

  static Future<BlockSchedule> create({
    required String name,
    List<ScheduleSlot>? slots,
    bool locked = false,
    int lockCooldownMinutes = 30,
    ScheduleEnforcementMode enforcementMode = ScheduleEnforcementMode.fullBlock,
    bool blockIsleInApp = false,
    bool enabled = true,
    int? scheduledActivationAtMs,
    int? scheduledDeactivationAtMs,
    bool reservationLocked = false,
  }) async {
    final list = loadAll();
    final s = BlockSchedule(
      id: 'sch_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      locked: locked,
      lockCooldownMinutes: lockCooldownMinutes.clamp(ScheduleConstants.minCooldownMinutes, 24 * 60),
      slots: slots ?? [],
      // locked:true 로 만든 스케줄을 이 함수 안에서 바로 copyWith+upsert 하면
      // ScheduleImportGuard(커밋먼트 락 보호)가 "이미 잠긴 스케줄 편집"으로 오인해
      // enforcementMode 등을 방금 만든 기본값(fullBlock)으로 되돌려버린다.
      // 최초 생성 시점에 최종 값을 바로 써서, 되돌아가도 이미 맞는 값이 되게 한다.
      // blockIsleInApp(브라우저/Safari 차단 플래그)도 같은 이유로 여기서 바로
      // 최종값을 써야 한다(cage 2026-07-11 이식 — blockIsleInApp이 계속
      // false로 저장되던 버그). 예약 스케줄 필드(enabled/scheduledActivation
      // AtMs 등, 2026-07-20 신설)도 같은 이유로 최초 생성 시점에 확정한다.
      enforcementMode: enforcementMode,
      blockIsleInApp: blockIsleInApp,
      enabled: enabled,
      scheduledActivationAtMs: scheduledActivationAtMs,
      scheduledDeactivationAtMs: scheduledDeactivationAtMs,
      reservationLocked: reservationLocked,
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
