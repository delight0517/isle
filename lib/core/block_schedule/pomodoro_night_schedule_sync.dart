import '../platform/blue_cloud_account_service.dart';
import 'block_schedule_store.dart';
import 'safety_baseline_service.dart';
import 'models/schedule_slot.dart';

enum PomodoroNightSyncResult { applied, noNightSchedule, commitmentLocked }

class PomodoroNightScheduleSync {
  PomodoroNightScheduleSync._();

  /// Auto Pomodoro uses 0=Sunday..6=Saturday; Isle slots use 0=Monday..6=Sunday.
  static List<ScheduleSlot> nightSlots(Map<String, dynamic> snapshot) {
    final settings = snapshot['settings'];
    final raw = snapshot['lockSchedule'] ??
        (settings is Map ? settings['lockSchedule'] : null);
    if (raw is! List) return const [];

    final slots = <ScheduleSlot>[];
    for (final item in raw) {
      if (item is! Map || item['enabled'] == false) continue;
      final start = (item['startMin'] as num?)?.toInt();
      final end = (item['endMin'] as num?)?.toInt();
      if (start == null ||
          end == null ||
          start < 0 ||
          start >= 1440 ||
          end < 0 ||
          end >= 1440 ||
          start == end) {
        continue;
      }
      final overnight = start > end || (start == 0 && end <= 600);
      if (!overnight) continue;
      final rawDays = item['days'];
      final parsedDays = rawDays is List
          ? rawDays
              .whereType<num>()
              .map((d) => d.toInt())
              .where((d) => d >= 0 && d <= 6)
              .toSet()
              .toList()
          : <int>[];
      final pomodoroDays =
          parsedDays.isEmpty ? List<int>.generate(7, (i) => i) : parsedDays;
      for (final day in pomodoroDays) {
        slots.add(ScheduleSlot(
          day: (day + 6) % 7,
          startMinute: start,
          endMinute: end,
        ));
      }
    }
    return slots;
  }

  /// Pulls Auto Pomodoro's source schedule into MOA's existing safety line.
  /// This trusted sync can update a normally locked schedule; reservation locks
  /// remain authoritative. It never writes to BlueCloud or unlocks user editing.
  static Future<PomodoroNightSyncResult> syncFromBlueCloud(
    BlueCloudAccountService account,
  ) async {
    final snapshot = await account.fetchPomodoroSnapshot();
    final slots = nightSlots(snapshot);
    if (slots.isEmpty) return PomodoroNightSyncResult.noNightSchedule;

    await BlockScheduleStore.ensureOpen();
    final schedule = BlockScheduleStore.loadAll()
        .where((s) => s.id == SafetyBaselineService.nightBlockScheduleId)
        .firstOrNull;
    if (schedule == null || schedule.reservationLocked) {
      return PomodoroNightSyncResult.commitmentLocked;
    }

    final updated = schedule.copyWith(
      slots: slots,
      enabled: true,
    );
    await BlockScheduleStore.upsert(updated);
    return PomodoroNightSyncResult.applied;
  }
}
