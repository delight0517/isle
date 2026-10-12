import '../services/isle_app_log_service.dart';
import 'block_schedule_enforcement_service.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'models/pending_schedule_field_edit.dart';
import 'models/schedule_enforcement_mode.dart';
import 'models/schedule_slot.dart';
import 'schedule_edit_guard.dart';
import 'schedule_lock_phase.dart';
import 'schedule_lock_service.dart';
import 'schedule_notification_service.dart';
import 'schedule_pending_field_store.dart';

enum ScheduleFieldChangeOutcomeKind {
  immediate,
  scheduled,
  alreadyPending,
  noop,
}

class ScheduleFieldChangeOutcome {
  const ScheduleFieldChangeOutcome._(this.kind, {this.remaining, this.startedCountdown = false});

  final ScheduleFieldChangeOutcomeKind kind;
  final Duration? remaining;
  final bool startedCountdown;

  factory ScheduleFieldChangeOutcome.immediate() =>
      const ScheduleFieldChangeOutcome._(ScheduleFieldChangeOutcomeKind.immediate);

  factory ScheduleFieldChangeOutcome.scheduled(Duration remaining, {bool startedCountdown = false}) =>
      ScheduleFieldChangeOutcome._(
        ScheduleFieldChangeOutcomeKind.scheduled,
        remaining: remaining,
        startedCountdown: startedCountdown,
      );

  factory ScheduleFieldChangeOutcome.alreadyPending(Duration remaining) =>
      ScheduleFieldChangeOutcome._(
        ScheduleFieldChangeOutcomeKind.alreadyPending,
        remaining: remaining,
      );

  factory ScheduleFieldChangeOutcome.noop() =>
      const ScheduleFieldChangeOutcome._(ScheduleFieldChangeOutcomeKind.noop);
}

/// 스케줄 잠금 중 시간표·이름·모드·전체 on/off 변경 예약 → 편집 창에서 자동
/// 적용 + 알림. [SchedulePendingTargetService](앱 타깃 전용)와 동일한 패턴을
/// ①②단계(시간표·이름·모드·enabled)까지 확장한 것 — 2026-07-20 사용자 요청,
/// "수동으로 적용을 눌러도 자동으로 timelock 이후에 적용되는 방식".
class SchedulePendingFieldService {
  SchedulePendingFieldService._();

  static String formatRemaining(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '$h시간 $m분 후 적용';
    if (m > 0) return '$m분 후 적용';
    final s = d.inSeconds.remainder(60);
    return s > 0 ? '$s초 후 적용' : '곧 적용';
  }

  /// [current]와 [desired]를 비교해 실제로 바뀌는 필드만 담은 diff.
  /// 아무것도 안 바뀌면 null.
  static PendingScheduleFieldEdit? _diff(BlockSchedule current, BlockSchedule desired) {
    String? name;
    List<ScheduleSlot>? slots;
    ScheduleEnforcementMode? enforcementMode;
    bool? enabled;

    if (desired.name != current.name) name = desired.name;
    if (!_slotsEqual(desired.slots, current.slots)) slots = desired.slots;
    if (desired.enforcementMode != current.enforcementMode) {
      enforcementMode = desired.enforcementMode;
    }
    if (desired.enabled != current.enabled) enabled = desired.enabled;

    if (name == null && slots == null && enforcementMode == null && enabled == null) {
      return null;
    }
    return PendingScheduleFieldEdit(
      scheduleId: current.id,
      applyAtMs: 0,
      scheduledAtMs: 0,
      name: name,
      slots: slots,
      enforcementMode: enforcementMode,
      enabled: enabled,
    );
  }

  static bool _slotsEqual(List<ScheduleSlot> a, List<ScheduleSlot> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].day != b[i].day ||
          a[i].startMinute != b[i].startMinute ||
          a[i].endMinute != b[i].endMinute) {
        return false;
      }
    }
    return true;
  }

  static Future<ScheduleFieldChangeOutcome> requestFieldChange({
    required BlockSchedule current,
    required BlockSchedule desired,
  }) async {
    await SchedulePendingFieldStore.ensureOpen();
    await processDue();

    final diff = _diff(current, desired);
    if (diff == null) return ScheduleFieldChangeOutcome.noop();

    if (!ScheduleEditGuard.isCommitmentLocked(current)) {
      await BlockScheduleStore.upsert(desired);
      await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
      await SchedulePendingFieldStore.cancelFor(current.id);
      return ScheduleFieldChangeOutcome.immediate();
    }

    final existing = SchedulePendingFieldStore.findFor(current.id);
    final plan = await _planApply(current);
    final pending = PendingScheduleFieldEdit(
      scheduleId: current.id,
      applyAtMs: plan.applyAt.millisecondsSinceEpoch,
      scheduledAtMs: existing?.scheduledAtMs ?? DateTime.now().millisecondsSinceEpoch,
      name: diff.name,
      slots: diff.slots,
      enforcementMode: diff.enforcementMode,
      enabled: diff.enabled,
    );
    await SchedulePendingFieldStore.upsertMerged(pending);
    await _refreshEditReminder(current, plan.applyAt);

    if (existing != null && !plan.startedCountdown) {
      return ScheduleFieldChangeOutcome.alreadyPending(plan.applyAt.difference(DateTime.now()));
    }
    return ScheduleFieldChangeOutcome.scheduled(
      plan.applyAt.difference(DateTime.now()),
      startedCountdown: plan.startedCountdown,
    );
  }

  static Future<int> processDue() async {
    await SchedulePendingFieldStore.ensureOpen();
    await BlockScheduleStore.ensureOpen();
    await ScheduleLockService.finalizeExpiredLocks();

    final pending = SchedulePendingFieldStore.loadAll();
    if (pending.isEmpty) return 0;

    var applied = 0;
    final appliedIds = <String>[];
    for (final p in pending) {
      if (p.applyAt.isAfter(DateTime.now())) continue;
      final schedule =
          BlockScheduleStore.loadAll().where((s) => s.id == p.scheduleId).firstOrNull;
      if (schedule == null) {
        appliedIds.add(p.scheduleId);
        continue;
      }
      if (!ScheduleLockService.canEditSchedule(schedule)) continue;

      final updated = schedule.copyWith(
        name: p.name,
        slots: p.slots,
        enforcementMode: p.enforcementMode,
        enabled: p.enabled,
      );
      await BlockScheduleStore.upsert(updated);
      appliedIds.add(p.scheduleId);
      applied++;
      await ScheduleNotificationService.cancelTargetEditReminder(p.scheduleId);
      IsleAppLogService.log('Schedule pending field edit applied ${p.scheduleId}');
    }

    if (appliedIds.isNotEmpty) {
      await SchedulePendingFieldStore.removeApplied(appliedIds);
      await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    }
    return applied;
  }

  static Future<void> tryApplyForSchedule(String scheduleId) async {
    await SchedulePendingFieldStore.ensureOpen();
    final has = SchedulePendingFieldStore.findFor(scheduleId) != null;
    if (!has) return;
    await processDue();
  }

  static Future<void> cancel(String scheduleId) => SchedulePendingFieldStore.cancelFor(scheduleId);

  static PendingScheduleFieldEdit? pendingFor(String scheduleId) =>
      SchedulePendingFieldStore.findFor(scheduleId);

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
    try {
      await ScheduleNotificationService.scheduleTargetEditReminder(
        schedule: schedule,
        applyAt: applyAt,
        pendingCount: 1,
      );
    } catch (e, st) {
      IsleAppLogService.log(
        'Schedule pending field edit reminder skipped: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
    }
  }
}

class _ApplyPlan {
  const _ApplyPlan({required this.applyAt, required this.startedCountdown});

  final DateTime applyAt;
  final bool startedCountdown;
}
