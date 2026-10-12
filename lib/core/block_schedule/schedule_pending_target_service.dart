import '../services/isle_app_log_service.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'models/pending_schedule_target_edit.dart';
import 'models/schedule_app_target_entry.dart';
import 'schedule_app_targets_service.dart';
import 'schedule_app_targets_store.dart';
import 'schedule_edit_guard.dart';
import 'schedule_lock_phase.dart';
import 'schedule_lock_service.dart';
import 'schedule_notification_service.dart';
import 'schedule_pending_target_store.dart';

enum ScheduleTargetChangeOutcomeKind {
  immediate,
  scheduled,
  alreadyPending,
  cancelled,
}

class ScheduleTargetChangeOutcome {
  const ScheduleTargetChangeOutcome._(this.kind, {this.remaining, this.startedCountdown = false});

  final ScheduleTargetChangeOutcomeKind kind;
  final Duration? remaining;
  final bool startedCountdown;

  factory ScheduleTargetChangeOutcome.immediate() =>
      const ScheduleTargetChangeOutcome._(ScheduleTargetChangeOutcomeKind.immediate);

  factory ScheduleTargetChangeOutcome.scheduled(Duration remaining, {bool startedCountdown = false}) =>
      ScheduleTargetChangeOutcome._(
        ScheduleTargetChangeOutcomeKind.scheduled,
        remaining: remaining,
        startedCountdown: startedCountdown,
      );

  factory ScheduleTargetChangeOutcome.alreadyPending(Duration remaining) =>
      ScheduleTargetChangeOutcome._(
        ScheduleTargetChangeOutcomeKind.alreadyPending,
        remaining: remaining,
      );

  factory ScheduleTargetChangeOutcome.cancelled() =>
      const ScheduleTargetChangeOutcome._(ScheduleTargetChangeOutcomeKind.cancelled);
}

/// 스케줄 잠금 중 앱 타깃 추가·제거 예약 → 편집 창에서 자동 적용 + 알림
class SchedulePendingTargetService {
  SchedulePendingTargetService._();

  static bool entriesEqual(ScheduleAppTargetEntry a, ScheduleAppTargetEntry b) =>
      a.targetId == b.targetId &&
      a.blockInSlot == b.blockInSlot &&
      a.limitEnabled == b.limitEnabled &&
      a.limitMinutes == b.limitMinutes &&
      a.windowMinutes == b.windowMinutes;

  static String formatRemaining(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '$h시간 $m분 후 적용';
    if (m > 0) return '$m분 후 적용';
    final s = d.inSeconds.remainder(60);
    return s > 0 ? '$s초 후 적용' : '곧 적용';
  }

  static String actionLabel(ScheduleAppTargetEntry desired, ScheduleAppTargetEntry current) {
    if (desired.blockInSlot && !current.blockInSlot) return '추가';
    if (!desired.blockInSlot && current.blockInSlot) return '제거';
    if (desired.limitEnabled != current.limitEnabled) {
      return desired.limitEnabled ? '한도 켜기' : '한도 끄기';
    }
    return '변경';
  }

  static Future<ScheduleTargetChangeOutcome> requestEntryChange({
    required BlockSchedule schedule,
    required ScheduleAppTargetEntry desired,
    required ScheduleAppTargetEntry currentPersisted,
  }) async {
    await SchedulePendingTargetStore.ensureOpen();
    await processDue();

    if (!ScheduleEditGuard.isCommitmentLocked(schedule)) {
      await _applyEntry(schedule, desired);
      await SchedulePendingTargetStore.cancelEntry(schedule.id, desired.targetId);
      return ScheduleTargetChangeOutcome.immediate();
    }

    if (entriesEqual(desired, currentPersisted)) {
      await SchedulePendingTargetStore.cancelEntry(schedule.id, desired.targetId);
      return ScheduleTargetChangeOutcome.cancelled();
    }

    final existing = SchedulePendingTargetStore.findEntry(schedule.id, desired.targetId);
    if (existing != null && entriesEqual(existing.entry!, desired)) {
      return ScheduleTargetChangeOutcome.alreadyPending(existing.remaining());
    }

    final plan = await _planApply(schedule);
    final pending = PendingScheduleTargetEdit(
      scheduleId: schedule.id,
      kind: PendingScheduleTargetKind.entry,
      targetId: desired.targetId,
      entry: desired,
      applyAtMs: plan.applyAt.millisecondsSinceEpoch,
      scheduledAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await SchedulePendingTargetStore.upsert(pending);
    await _refreshEditReminder(schedule, plan.applyAt);

    return ScheduleTargetChangeOutcome.scheduled(
      plan.applyAt.difference(DateTime.now()),
      startedCountdown: plan.startedCountdown,
    );
  }

  static Future<void> queueIosPickSync(BlockSchedule schedule) async {
    if (!ScheduleEditGuard.isCommitmentLocked(schedule)) return;

    final plan = await _planApply(schedule);
    await SchedulePendingTargetStore.upsert(
      PendingScheduleTargetEdit(
        scheduleId: schedule.id,
        kind: PendingScheduleTargetKind.iosPickSync,
        applyAtMs: plan.applyAt.millisecondsSinceEpoch,
        scheduledAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _refreshEditReminder(schedule, plan.applyAt);
  }

  static Future<int> processDue() async {
    await SchedulePendingTargetStore.ensureOpen();
    await BlockScheduleStore.ensureOpen();
    await ScheduleLockService.finalizeExpiredLocks();

    final pending = SchedulePendingTargetStore.loadAll();
    if (pending.isEmpty) return 0;

    var applied = 0;
    final done = <PendingScheduleTargetEdit>[];
    final bySchedule = <String, List<PendingScheduleTargetEdit>>{};
    for (final p in pending) {
      bySchedule.putIfAbsent(p.scheduleId, () => []).add(p);
    }

    for (final entry in bySchedule.entries) {
      final scheduleId = entry.key;
      final schedule =
          BlockScheduleStore.loadAll().where((s) => s.id == scheduleId).firstOrNull;
      if (schedule == null) {
        done.addAll(entry.value);
        continue;
      }
      if (!ScheduleLockService.canEditSchedule(schedule)) continue;

      final due = entry.value.where((p) => !p.applyAt.isAfter(DateTime.now())).toList();
      if (due.isEmpty) continue;

      final entryChanges = due
          .where((p) => p.kind == PendingScheduleTargetKind.entry && p.entry != null)
          .map((p) => p.entry!)
          .toList();
      final needsIosSync = due.any((p) => p.kind == PendingScheduleTargetKind.iosPickSync);

      if (entryChanges.isNotEmpty) {
        await _applyEntries(schedule, entryChanges);
      } else if (needsIosSync) {
        await ScheduleAppTargetsService.saveAndSync(
          scheduleId: schedule.id,
          entries: ScheduleAppTargetsStore.mergeWithCatalog(
            ScheduleAppTargetsStore.loadForSchedule(schedule.id),
          ),
          schedule: schedule,
        );
      }

      done.addAll(due);
      applied += due.length;
      await ScheduleNotificationService.cancelTargetEditReminder(schedule.id);
      IsleAppLogService.log(
        'Schedule pending targets applied $scheduleId (${due.length} item(s))',
      );
    }

    if (done.isNotEmpty) {
      await SchedulePendingTargetStore.removeApplied(done);
    }
    return applied;
  }

  static Future<void> tryApplyForSchedule(String scheduleId) async {
    await SchedulePendingTargetStore.ensureOpen();
    final has = SchedulePendingTargetStore.loadForSchedule(scheduleId).isNotEmpty;
    if (!has) return;
    await processDue();
  }

  static Future<void> cancelEntry(String scheduleId, String targetId) =>
      SchedulePendingTargetStore.cancelEntry(scheduleId, targetId);

  static PendingScheduleTargetEdit? pendingEntry(String scheduleId, String targetId) =>
      SchedulePendingTargetStore.findEntry(scheduleId, targetId);

  static PendingScheduleTargetEdit? pendingIosPick(String scheduleId) =>
      SchedulePendingTargetStore.findIosPickSync(scheduleId);

  static Future<_ApplyPlan> _planApply(BlockSchedule schedule) async {
    final phase = ScheduleLockService.phase(schedule);
    final now = DateTime.now();

    if (phase == ScheduleLockPhase.countdown) {
      final left = ScheduleLockService.countdownRemaining(schedule) ?? Duration.zero;
      return _ApplyPlan(applyAt: now.add(left), startedCountdown: false);
    }

    if (phase == ScheduleLockPhase.locked) {
      await ScheduleLockService.startUnlockCountdown(schedule.id);
      final updated = BlockScheduleStore.loadAll().firstWhere((s) => s.id == schedule.id);
      final applyAt = now.add(Duration(minutes: updated.lockCooldownMinutes));
      return _ApplyPlan(applyAt: applyAt, startedCountdown: true);
    }

    return _ApplyPlan(applyAt: now, startedCountdown: false);
  }

  static Future<void> _refreshEditReminder(BlockSchedule schedule, DateTime applyAt) async {
    final count = SchedulePendingTargetStore.loadForSchedule(schedule.id).length;
    if (count == 0) return;
    try {
      await ScheduleNotificationService.scheduleTargetEditReminder(
        schedule: schedule,
        applyAt: applyAt,
        pendingCount: count,
      );
    } catch (e, st) {
      IsleAppLogService.log(
        'Schedule target edit reminder skipped: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
    }
  }

  static Future<void> _applyEntry(BlockSchedule schedule, ScheduleAppTargetEntry entry) =>
      _applyEntries(schedule, [entry]);

  static Future<void> _applyEntries(
    BlockSchedule schedule,
    List<ScheduleAppTargetEntry> changes,
  ) async {
    await ScheduleAppTargetsStore.ensureOpen();
    var entries = ScheduleAppTargetsStore.mergeWithCatalog(
      ScheduleAppTargetsStore.loadForSchedule(schedule.id),
    );
    for (final change in changes) {
      final i = entries.indexWhere((e) => e.targetId == change.targetId);
      if (i >= 0) {
        entries = [...entries]..[i] = change;
      } else {
        entries = [...entries, change];
      }
    }
    await ScheduleAppTargetsService.saveAndSync(
      scheduleId: schedule.id,
      entries: entries,
      schedule: schedule,
    );
  }
}

class _ApplyPlan {
  const _ApplyPlan({required this.applyAt, required this.startedCountdown});

  final DateTime applyAt;
  final bool startedCountdown;
}
