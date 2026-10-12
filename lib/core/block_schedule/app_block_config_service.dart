import 'dart:async';
import 'dart:io' show Platform;

import '../ai/block_chat/block_chat_schedule_dedup.dart';
import '../intervention/schedule_screen_time_service.dart';
import '../intervention/schedule_screen_time_store.dart';
import '../platform/ios_rules_export_service.dart';
import '../platform/isle_apple_platform.dart';
import 'block_schedule_enforcement_service.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'models/schedule_app_target_entry.dart';
import 'models/schedule_enforcement_mode.dart';
import 'models/schedule_slot.dart';
import 'schedule_app_target_catalog.dart';
import 'schedule_app_targets_service.dart';
import 'schedule_app_targets_store.dart';

/// 카탈로그 앱 하나(카카오톡·인스타그램·틱톡 등)를 위한 통합 차단 설정 —
/// 홈 화면 카드 하나에서 [항상 차단]/[시간표]/[나눠 쓰기]를 전부 다루기 위해,
/// 이름이 고정된("$앱 차단 설정") 스케줄 정확히 1개만 찾거나 만든다.
/// 채팅 파서용 [BlockChatScheduleDedup.findNightSns]류의 이름·패턴 fuzzy 매칭은
/// 다른 앱 스케줄을 가로채는 co-mingle 버그의 원인이었으므로 여기선 절대 안 쓴다.
class AppBlockConfigService {
  AppBlockConfigService._();

  static String scheduleNameFor(String bundleId) {
    final bundle = ScheduleAppTargetCatalog.bundleFor(bundleId);
    final label = bundle?.label ?? bundleId;
    return '$label 차단 설정';
  }

  static List<String> targetIdsFor(String bundleId) =>
      ScheduleAppTargetCatalog.bundleFor(bundleId)?.targetIds ?? const [];

  static Future<BlockSchedule> loadOrCreate(String bundleId) async {
    final existing = await existingFor(bundleId);
    if (existing != null) return existing;
    return BlockScheduleStore.create(
      name: scheduleNameFor(bundleId),
      slots: const [],
      locked: false,
      enforcementMode: ScheduleEnforcementMode.fullBlock,
    );
  }

  /// 이 앱의 스케줄이 있다면 반환 (없으면 null — 카드에 "off" 상태로 보여주기 위함).
  ///
  /// 먼저 고정 이름("$앱 차단 설정")으로 찾고, 없으면 **채팅으로 만든 스케줄**
  /// (예: "카카오톡 야간 리필 (AI)")도 놓치지 않도록 이 앱의 targetId를
  /// blockInSlot/limitEnabled로 대상 삼고 있는 스케줄을 폭넓게 찾는다 —
  /// 2026-07-07: 이름이 안 맞아 채팅 스케줄이 홈 카드에 "미설정"으로 보이던 버그
  /// (챗이 스케줄을 만들 때 이 고정 이름 규약을 안 쓰기 때문에 발생).
  /// 찾으면 그 스케줄을 그대로 재사용(이름 유지) — 새로 만들면 중복 스케줄 생김.
  static Future<BlockSchedule?> existingFor(String bundleId) async {
    return (await schedulesFor(bundleId)).firstOrNull;
  }

  static Future<BlockSchedule?> scheduleById(String scheduleId) async {
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    return BlockScheduleStore.loadAll()
        .where((s) => s.id == scheduleId)
        .firstOrNull;
  }

  static Future<List<BlockSchedule>> schedulesFor(String bundleId) async {
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    final byName =
        BlockChatScheduleDedup.findExactName(scheduleNameFor(bundleId));
    final targetIds = targetIdsFor(bundleId).toSet();
    final out = <BlockSchedule>[];
    final seen = <String>{};

    void add(BlockSchedule? s) {
      if (s == null) return;
      if (seen.add(s.id)) out.add(s);
    }

    add(byName);
    if (targetIds.isNotEmpty) {
      for (final s in BlockScheduleStore.loadAll()) {
        final entries = ScheduleAppTargetsStore.loadForSchedule(s.id);
        final matches = entries.any(
          (e) =>
              targetIds.contains(e.targetId) &&
              (e.blockInSlot || e.limitEnabled),
        );
        if (matches) add(s);
      }
    }
    out.sort((a, b) {
      if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return out;
  }

  static Future<BlockSchedule> createAdditionalRule(
    String bundleId, {
    BlockSchedule? template,
  }) async {
    final bundle = ScheduleAppTargetCatalog.bundleFor(bundleId);
    final label = bundle?.label ?? bundleId;
    final existing = await schedulesFor(bundleId);
    final suffix = existing.length + 1;
    final source = template ?? existing.firstOrNull;
    final schedule = await BlockScheduleStore.create(
      name: '$label 규칙 $suffix',
      slots: source?.slots ?? const [],
      locked: source?.locked ?? false,
      lockCooldownMinutes: source?.lockCooldownMinutes ?? 30,
      enforcementMode:
          source?.enforcementMode ?? ScheduleEnforcementMode.fullBlock,
      blockIsleInApp: source?.blockIsleInApp ?? false,
    );
    final targetIds = targetIdsFor(bundleId).toSet();
    final sourceEntries = source == null
        ? const <ScheduleAppTargetEntry>[]
        : ScheduleAppTargetsStore.loadForSchedule(source.id);
    final entries = targetIds.isEmpty
        ? ScheduleAppTargetsStore.loadForSchedule(schedule.id)
        : targetIds.map((tid) {
            final existingEntry =
                sourceEntries.where((e) => e.targetId == tid).firstOrNull;
            return existingEntry ??
                ScheduleAppTargetEntry(targetId: tid, blockInSlot: true);
          }).toList();
    await ScheduleAppTargetsStore.saveForSchedule(schedule.id, entries);
    await _finishSync(schedule.id, schedule);
    return schedule;
  }

  static Future<BlockSchedule> _loadTargetSchedule(
    String bundleId, {
    String? scheduleId,
  }) async {
    if (scheduleId != null) {
      final byId = await scheduleById(scheduleId);
      if (byId != null) return byId;
    }
    return loadOrCreate(bundleId);
  }

  static Future<void> _saveEntries(
    String scheduleId,
    String bundleId,
    ScheduleAppTargetEntry Function(ScheduleAppTargetEntry e) mapper,
  ) async {
    final targetIds = targetIdsFor(bundleId);
    final entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(scheduleId),
    ).map((e) => targetIds.contains(e.targetId) ? mapper(e) : e).toList();
    await ScheduleAppTargetsStore.saveForSchedule(scheduleId, entries);
  }

  static Future<void> _ensureScreenTimePicked(
    String scheduleId,
    String bundleId,
  ) async {
    if (!IsleApplePlatform.isScreenTimeHost && !Platform.isAndroid) return;
    if (ScheduleScreenTimeStore.appCountFor(scheduleId, bundleId: bundleId) >
        0) {
      return;
    }
    await ScheduleScreenTimeStore.ensureOpen();
    await ScheduleScreenTimeService.pickForSchedule(
      scheduleId,
      bundleId: bundleId,
      additiveOnly: true,
      deferEnforcement: true,
    );
  }

  static Future<void> _finishSync(
      String scheduleId, BlockSchedule schedule) async {
    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: scheduleId,
      entries: ScheduleAppTargetsStore.loadForSchedule(scheduleId),
      schedule: schedule,
    );
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    unawaited(IosRulesExportService.exportNow());
  }

  /// 24시간 항상 차단 (프리셋(QuickOsBlockService)이 없는 카탈로그 앱 전용 —
  /// 카카오톡/유튜브/유튜브뮤직처럼 별도 상시 스위치가 있는 앱은 그 경로를 쓴다).
  static Future<BlockSchedule> applyAlwaysBlock(
    String bundleId,
    bool on, {
    String? scheduleId,
  }) async {
    final schedule =
        await _loadTargetSchedule(bundleId, scheduleId: scheduleId);
    final slots = on
        ? [
            for (var d = 0; d < 7; d++)
              ScheduleSlot(day: d, startMinute: 0, endMinute: 1439),
          ]
        : const <ScheduleSlot>[];
    final updated = schedule.copyWith(
      enabled: on,
      enforcementMode: ScheduleEnforcementMode.fullBlock,
      slots: slots,
    );
    await BlockScheduleStore.upsert(updated);
    await _saveEntries(
      schedule.id,
      bundleId,
      (e) => e.copyWith(blockInSlot: on, limitEnabled: false),
    );
    if (on) await _ensureScreenTimePicked(schedule.id, bundleId);
    await _finishSync(schedule.id, updated);
    return updated;
  }

  /// 특정 요일·시간대에 완전 차단.
  static Future<BlockSchedule> applyTimeWindow(
    String bundleId, {
    required List<ScheduleSlot> slots,
    String? scheduleId,
  }) async {
    final schedule =
        await _loadTargetSchedule(bundleId, scheduleId: scheduleId);
    final updated = schedule.copyWith(
      enabled: true,
      enforcementMode: ScheduleEnforcementMode.fullBlock,
      slots: slots,
    );
    await BlockScheduleStore.upsert(updated);
    await _saveEntries(
      schedule.id,
      bundleId,
      (e) => e.copyWith(blockInSlot: true, limitEnabled: false),
    );
    await _ensureScreenTimePicked(schedule.id, bundleId);
    await _finishSync(schedule.id, updated);
    return updated;
  }

  /// 특정 요일·시간대에 "N분 쓰고 M분 대기" 나눠 쓰기(리필).
  static Future<BlockSchedule> applyRefill(
    String bundleId, {
    required List<ScheduleSlot> slots,
    required int sessionMinutes,
    required int windowMinutes,
    String? scheduleId,
  }) async {
    final schedule =
        await _loadTargetSchedule(bundleId, scheduleId: scheduleId);
    final updated = schedule.copyWith(
      enabled: true,
      enforcementMode: ScheduleEnforcementMode.limitInSlot,
      slots: slots,
    );
    await BlockScheduleStore.upsert(updated);
    await _saveEntries(
      schedule.id,
      bundleId,
      (e) => e.copyWith(
        blockInSlot: false,
        limitEnabled: true,
        limitMinutes: sessionMinutes.clamp(1, 60),
        windowMinutes: windowMinutes.clamp(5, 1440),
      ),
    );
    await _ensureScreenTimePicked(schedule.id, bundleId);
    await _finishSync(schedule.id, updated);
    return updated;
  }

  /// 스케줄의 시간대·모드는 그대로 두고 켜기/끄기만 — 홈 화면 스위치용
  /// (2026-07-20). [applyOff]는 슬롯·타깃까지 지우는 "설정 초기화"라 스위치를
  /// 다시 켰을 때 이전에 골라둔 시간대/나눠쓰기 값이 사라지는데, 홈 스위치는
  /// "이미 정해둔 블락이 지금 도는지"만 토글해야 하므로(사용자 명시 요청)
  /// 이 메서드가 그 의미를 담당한다. 스케줄이 아직 없고 켜는 경우엔 24시간
  /// 항상 차단을 기본값으로 새로 만든다.
  static Future<BlockSchedule> setEnabled(
    String bundleId,
    bool on, {
    String? scheduleId,
  }) async {
    final schedule =
        await _loadTargetSchedule(bundleId, scheduleId: scheduleId);
    if (on && schedule.slots.isEmpty) {
      return applyAlwaysBlock(bundleId, true, scheduleId: schedule.id);
    }
    final updated = schedule.copyWith(enabled: on);
    await BlockScheduleStore.upsert(updated);
    if (on) await _ensureScreenTimePicked(schedule.id, bundleId);
    await _finishSync(schedule.id, updated);
    return updated;
  }

  /// 이 앱의 차단·한도를 전부 끈다 (스케줄 자체는 재사용을 위해 남겨둠).
  static Future<void> applyOff(String bundleId, {String? scheduleId}) async {
    final schedule = scheduleId != null
        ? await scheduleById(scheduleId)
        : await existingFor(bundleId);
    if (schedule == null) return;
    final updated = schedule.copyWith(enabled: false, slots: const []);
    await BlockScheduleStore.upsert(updated);
    await _saveEntries(
      schedule.id,
      bundleId,
      (e) => e.copyWith(blockInSlot: false, limitEnabled: false),
    );
    await _finishSync(schedule.id, updated);
  }
}
