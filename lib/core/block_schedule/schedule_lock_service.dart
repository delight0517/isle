import 'models/block_schedule.dart';
import 'schedule_constants.dart';
import 'schedule_lock_phase.dart';
import 'block_schedule_store.dart';

/// §2-B per-schedule lock state machine
class ScheduleLockService {
  ScheduleLockService._();

  static ScheduleLockPhase phase(BlockSchedule schedule, [DateTime? at]) {
    if (!schedule.locked) return ScheduleLockPhase.unlocked;

    final startedMs = schedule.unlockStartedAtMs;
    if (startedMs == null) return ScheduleLockPhase.locked;

    final now = at ?? DateTime.now();
    final started = DateTime.fromMillisecondsSinceEpoch(startedMs);
    final cooldownEnd = started.add(Duration(minutes: schedule.lockCooldownMinutes));
    final editEnd = schedule.unlockUntilMs != null
        ? DateTime.fromMillisecondsSinceEpoch(schedule.unlockUntilMs!)
        : cooldownEnd.add(const Duration(minutes: ScheduleConstants.editWindowMinutes));

    if (now.isBefore(cooldownEnd)) return ScheduleLockPhase.countdown;
    if (now.isBefore(editEnd)) return ScheduleLockPhase.editWindow;

    return ScheduleLockPhase.locked;
  }

  static bool isEffectivelyLocked(BlockSchedule schedule, [DateTime? at]) {
    final p = phase(schedule, at);
    return p == ScheduleLockPhase.locked || p == ScheduleLockPhase.countdown;
  }

  static bool canEditSchedule(BlockSchedule schedule, [DateTime? at]) =>
      phase(schedule, at) == ScheduleLockPhase.editWindow;

  static Duration? countdownRemaining(BlockSchedule schedule, [DateTime? at]) {
    if (phase(schedule, at) != ScheduleLockPhase.countdown) return null;
    final started = DateTime.fromMillisecondsSinceEpoch(schedule.unlockStartedAtMs!);
    final end = started.add(Duration(minutes: schedule.lockCooldownMinutes));
    final left = end.difference(at ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  static Duration? editWindowRemaining(BlockSchedule schedule, [DateTime? at]) {
    if (phase(schedule, at) != ScheduleLockPhase.editWindow) return null;
    final untilMs = schedule.unlockUntilMs;
    if (untilMs == null) return null;
    final end = DateTime.fromMillisecondsSinceEpoch(untilMs);
    final left = end.difference(at ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// 잠금 해제 카운트다운 시작 (쿨다운은 잠금 해제 상태에서만 변경 가능)
  static Future<BlockSchedule?> startUnlockCountdown(String scheduleId) async {
    final list = BlockScheduleStore.loadAll();
    final idx = list.indexWhere((s) => s.id == scheduleId);
    if (idx < 0) return null;
    final s = list[idx];
    if (!s.locked) return s;

    final now = DateTime.now();
    final editEnd = now.add(
      Duration(minutes: s.lockCooldownMinutes + ScheduleConstants.editWindowMinutes),
    );
    final updated = s.copyWith(
      unlockStartedAtMs: now.millisecondsSinceEpoch,
      unlockUntilMs: editEnd.millisecondsSinceEpoch,
    );
    list[idx] = updated;
    await BlockScheduleStore.saveAll(list);
    return updated;
  }

  static Future<void> cancelUnlock(String scheduleId) async {
    final list = BlockScheduleStore.loadAll();
    final idx = list.indexWhere((s) => s.id == scheduleId);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(clearUnlock: true);
    await BlockScheduleStore.saveAll(list);
  }

  static Future<void> finalizeExpiredLocks() async {
    final list = BlockScheduleStore.loadAll();
    var changed = false;
    final now = DateTime.now();
    for (var i = 0; i < list.length; i++) {
      final s = list[i];
      if (s.unlockStartedAtMs == null) continue;
      final untilMs = s.unlockUntilMs;
      if (untilMs != null && now.isAfter(DateTime.fromMillisecondsSinceEpoch(untilMs))) {
        list[i] = s.copyWith(clearUnlock: true);
        changed = true;
      }
    }
    if (changed) await BlockScheduleStore.saveAll(list);
  }
}
