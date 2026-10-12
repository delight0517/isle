import 'dart:async';

import '../platform/ios_rules_export_service.dart';
import '../services/isle_user_defaults.dart';
import 'block_schedule_enforcement_service.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'models/schedule_slot.dart';
import 'schedule_app_targets_service.dart';
import 'schedule_app_targets_store.dart';

/// Isle 인앱 유튜브 — 매일 아침(0시~) 차단 스케줄 (수동·AI 챗 공용)
class IsleYoutubeScheduleService {
  IsleYoutubeScheduleService._();

  static Future<BlockSchedule> applyMorningBlock({
    required int endHour,
    int endMinute = 0,
    String? scheduleName,
    List<int> days = const [0, 1, 2, 3, 4, 5, 6],
  }) async {
    final endMin = (endHour * 60 + endMinute).clamp(1, 1439);
    final slots = [
      for (final d in days)
        ScheduleSlot(day: d.clamp(0, 6), startMinute: 0, endMinute: endMin),
    ];
    return _applySlots(
      slots: slots,
      name: scheduleName?.trim().isNotEmpty == true
          ? scheduleName!.trim()
          : '아침 Isle 유튜브',
    );
  }

  /// 허용 창 — [startMin]~[endMin]만 보게 하고 나머지 시간을 차단(보완 슬롯).
  /// 예: 평일 15:00–19:00 허용 → 매일 00:00–15:00 + 19:00–24:00 차단.
  static Future<BlockSchedule> applyAllowWindow({
    required int startMinute,
    required int endMinute,
    String? scheduleName,
    List<int> days = const [0, 1, 2, 3, 4, 5, 6],
  }) async {
    final start = startMinute.clamp(0, 1439);
    final end = endMinute.clamp(1, 1440);
    final slots = <ScheduleSlot>[];
    for (final d in days) {
      final day = d.clamp(0, 6);
      // 허용 창 앞 (00:00 → start)
      if (start > 0) {
        slots.add(ScheduleSlot(day: day, startMinute: 0, endMinute: start));
      }
      // 허용 창 뒤 (end → 24:00)
      if (end < 1440) {
        slots.add(ScheduleSlot(day: day, startMinute: end, endMinute: 1440));
      }
    }
    return _applySlots(
      slots: slots,
      name: scheduleName?.trim().isNotEmpty == true
          ? scheduleName!.trim()
          : '유튜브 허용 창',
    );
  }

  static Future<BlockSchedule> _applySlots({
    required List<ScheduleSlot> slots,
    required String name,
  }) async {
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);

    BlockSchedule? existing;
    for (final s in BlockScheduleStore.loadAll()) {
      if (s.name == name) {
        existing = s;
        break;
      }
    }

    final schedule = existing ??
        await BlockScheduleStore.create(
          name: name,
          slots: slots,
          locked: true,
          lockCooldownMinutes: 30,
        );

    var enabled = schedule.copyWith(
      enabled: true,
      slots: slots,
      locked: true,
    );
    await BlockScheduleStore.upsert(enabled);

    final entries = ScheduleAppTargetsStore.loadForSchedule(schedule.id)
        .map((e) => e.targetId == 'isle_youtube' ? e.copyWith(blockInSlot: true) : e)
        .toList();
    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: schedule.id,
      entries: entries,
      schedule: enabled,
    );

    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    unawaited(IosRulesExportService.exportNow());
    return BlockScheduleStore.loadAll().firstWhere((s) => s.id == schedule.id);
  }

  static String formatEndLabel(int endMinute) {
    final h = endMinute ~/ 60;
    final m = endMinute % 60;
    if (m == 0) return '$h시';
    return '$h시 $m분';
  }
}
