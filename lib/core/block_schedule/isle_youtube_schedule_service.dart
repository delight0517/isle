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
    await BlockScheduleStore.ensureOpen();
    await ScheduleAppTargetsStore.ensureOpen();
    await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);

    final endMin = (endHour * 60 + endMinute).clamp(1, 1439);
    final slots = [
      for (final d in days)
        ScheduleSlot(day: d.clamp(0, 6), startMinute: 0, endMinute: endMin),
    ];
    final name = scheduleName?.trim().isNotEmpty == true
        ? scheduleName!.trim()
        : '아침 Isle 유튜브';

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
