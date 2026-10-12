import 'dart:async';

import 'models/block_schedule.dart';
import 'block_schedule_enforcement_service.dart';
import 'block_schedule_store.dart';
import 'schedule_app_target_catalog.dart';
import 'schedule_app_targets_service.dart';
import 'schedule_app_targets_store.dart';
import 'schedule_edit_guard.dart';
import 'schedule_lock_phase.dart';
import 'schedule_lock_service.dart';
import 'schedule_notification_service.dart';
import '../services/isle_user_defaults.dart';
import '../youtube/youtube_timelock_service.dart';
import 'schedule_block_explain_service.dart';

/// 차단 이유 시트 — 스와이프·탭으로 규칙 완화 (스케줄 잠금 대기 포함)
class ScheduleBlockRelaxService {
  ScheduleBlockRelaxService._();

  static Future<ScheduleBlockRelaxResult> relaxItem(ScheduleBlockExplainItem item) async {
    final action = item.relaxAction;
    if (action == null) {
      return const ScheduleBlockRelaxResult(
        ok: false,
        message: '이 항목은 여기서 끌 수 없어요',
      );
    }

    if (action == ScheduleBlockRelaxAction.timelockOff) {
      return _requestYoutubeTimelockOff();
    }

    final scheduleId = item.scheduleId;
    if (scheduleId == null) {
      return const ScheduleBlockRelaxResult(
        ok: false,
        message: '스케줄 정보가 없어요',
      );
    }

    await BlockScheduleStore.ensureOpen();
    var schedule = BlockScheduleStore.loadAll().where((s) => s.id == scheduleId).firstOrNull;
    if (schedule == null) {
      return const ScheduleBlockRelaxResult(
        ok: false,
        message: '스케줄을 찾을 수 없어요',
      );
    }

    if (ScheduleEditGuard.isCommitmentLocked(schedule)) {
      final phase = ScheduleLockService.phase(schedule);
      if (phase == ScheduleLockPhase.countdown) {
        final left = ScheduleLockService.countdownRemaining(schedule);
        final min = left?.inMinutes ?? schedule.lockCooldownMinutes;
        return ScheduleBlockRelaxResult(
          ok: false,
          message: '잠금 해제 대기 중 · 약 $min분 후 다시 스와이프하세요',
          needsCountdown: true,
          scheduleId: scheduleId,
          relaxAction: action,
        );
      }
      await IsleUserDefaults.setPendingBlockRelax('$scheduleId|${action.name}');
      await ScheduleLockService.startUnlockCountdown(scheduleId);
      schedule = BlockScheduleStore.loadAll().firstWhere((s) => s.id == scheduleId);
      unawaited(ScheduleNotificationService.scheduleUnlockCountdownReminder(
        schedule: schedule,
        readyAt: DateTime.now().add(Duration(minutes: schedule.lockCooldownMinutes)),
      ));
      return ScheduleBlockRelaxResult(
        ok: true,
        message: '「${schedule.name}」잠금 해제 ${schedule.lockCooldownMinutes}분 대기 시작 — 끝나면 자동으로 적용돼요',
        startedCountdown: true,
      );
    }

    return _applyNow(schedule, action);
  }

  /// AI 챗·일괄 해제 — 잠금·편집 창 처리 (여러 스케줄 순회용)
  static Future<ScheduleBlockRelaxResult> relaxScheduleWithLocks(
    BlockSchedule schedule,
    ScheduleBlockRelaxAction action,
  ) async {
    // 안전 라인도 이제 이 경로(스와이프/relax_block, "모든 차단 초기화"·
    // "겹친 스케줄 여러 개 완화" 요청이 여기로 온다)로 완화 "요청"까지는
    // 갈 수 있다 — 다만 안전 라인 스케줄은 항상 locked:true라서 아래
    // ScheduleEditGuard.isCommitmentLocked 분기를 그대로 타고, 15분
    // 타임락 대기 없이는 절대 즉시 적용되지 않는다(2026-07-20 사용자 확정
    // — 일반 잠긴 스케줄과 동일하게 취급).
    if (action == ScheduleBlockRelaxAction.timelockOff) {
      return _requestYoutubeTimelockOff();
    }

    if (ScheduleEditGuard.isCommitmentLocked(schedule)) {
      final phase = ScheduleLockService.phase(schedule);
      if (phase == ScheduleLockPhase.editWindow) {
        return _applyNow(schedule, action);
      }
      if (phase == ScheduleLockPhase.countdown) {
        return ScheduleBlockRelaxResult(
          ok: false,
          message: '타임락 대기 중',
          needsCountdown: true,
          scheduleId: schedule.id,
          relaxAction: action,
        );
      }
      await IsleUserDefaults.setPendingBlockRelax('${schedule.id}|${action.name}');
      await ScheduleLockService.startUnlockCountdown(schedule.id);
      unawaited(ScheduleNotificationService.scheduleUnlockCountdownReminder(
        schedule: schedule,
        readyAt: DateTime.now().add(Duration(minutes: schedule.lockCooldownMinutes)),
      ));
      return ScheduleBlockRelaxResult(
        ok: true,
        message: '타임락 대기 시작',
        startedCountdown: true,
        scheduleId: schedule.id,
        relaxAction: action,
      );
    }

    return _applyNow(schedule, action);
  }

  static Future<void> tryApplyPendingRelax() async {
    final raw = IsleUserDefaults.pendingBlockRelax;
    if (raw == null || raw.isEmpty) return;

    final parts = raw.split('|');
    if (parts.length != 2) {
      await IsleUserDefaults.clearPendingBlockRelax();
      return;
    }
    final scheduleId = parts[0];
    final action = ScheduleBlockRelaxAction.values
        .where((a) => a.name == parts[1])
        .firstOrNull;
    if (action == null) {
      await IsleUserDefaults.clearPendingBlockRelax();
      return;
    }

    await BlockScheduleStore.ensureOpen();
    await ScheduleLockService.finalizeExpiredLocks();
    final schedule = BlockScheduleStore.loadAll().where((s) => s.id == scheduleId).firstOrNull;
    if (schedule == null) {
      await IsleUserDefaults.clearPendingBlockRelax();
      return;
    }
    if (!ScheduleEditGuard.canEditScheduleFields(schedule)) return;

    final result = await _applyNow(schedule, action);
    if (result.applied) {
      await IsleUserDefaults.clearPendingBlockRelax();
    }
  }

  static Future<ScheduleBlockRelaxResult> _applyNow(
    BlockSchedule schedule,
    ScheduleBlockRelaxAction action,
  ) async {
    await ScheduleAppTargetsStore.ensureOpen();
    var updated = schedule;

    switch (action) {
      case ScheduleBlockRelaxAction.domainsOff:
        updated = updated.copyWith(domains: const []);
        await BlockScheduleStore.upsert(updated);
      case ScheduleBlockRelaxAction.isleInAppOff:
        updated = updated.copyWith(blockIsleInApp: false);
        await BlockScheduleStore.upsert(updated);
      case ScheduleBlockRelaxAction.youtubeOff:
        updated = updated.copyWith(domains: const [], blockIsleInApp: false);
        final entries = ScheduleAppTargetsStore.loadForSchedule(schedule.id)
            .map((e) {
              final def = ScheduleAppTargetCatalog.defFor(e.targetId);
              if (def == null) return e;
              if (def.bundleId == 'youtube' ||
                  def.bundleId == 'youtube_music' ||
                  def.id == 'isle_youtube') {
                return e.copyWith(blockInSlot: false, limitEnabled: false);
              }
              return e;
            })
            .toList();
        await ScheduleAppTargetsService.saveAndSync(
          scheduleId: schedule.id,
          entries: entries,
          schedule: updated,
        );
        await BlockScheduleStore.upsert(updated);
      case ScheduleBlockRelaxAction.instagramOff:
        final igEntries = ScheduleAppTargetsStore.loadForSchedule(schedule.id)
            .map((e) {
              final def = ScheduleAppTargetCatalog.defFor(e.targetId);
              if (def == null) return e;
              if (def.bundleId == 'instagram_feed' ||
                  def.bundleId == 'instagram_dm' ||
                  def.id.contains('instagram')) {
                return e.copyWith(blockInSlot: false, limitEnabled: false);
              }
              return e;
            })
            .toList();
        await ScheduleAppTargetsService.saveAndSync(
          scheduleId: schedule.id,
          entries: igEntries,
          schedule: updated,
        );
      case ScheduleBlockRelaxAction.scheduleOff:
        updated = updated.copyWith(enabled: false);
        await BlockScheduleStore.upsert(updated);
      case ScheduleBlockRelaxAction.timelockOff:
        await YoutubeTimelockService.disable();
    }
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);

    final label = switch (action) {
      ScheduleBlockRelaxAction.domainsOff => '도메인 쉴드',
      ScheduleBlockRelaxAction.isleInAppOff => 'Isle 인앱 차단',
      ScheduleBlockRelaxAction.youtubeOff => '유튜브 차단',
      ScheduleBlockRelaxAction.instagramOff => 'Instagram 차단',
      ScheduleBlockRelaxAction.scheduleOff => '스케줄',
      ScheduleBlockRelaxAction.timelockOff => '타임락',
    };

    return ScheduleBlockRelaxResult(
      ok: true,
      message: '「${schedule.name}」$label 끔',
      applied: true,
    );
  }

  static Future<ScheduleBlockRelaxResult> _requestYoutubeTimelockOff() async {
    final result = await YoutubeTimelockService.requestDisable();
    switch (result.kind) {
      case YoutubeTimelockDisableRequestKind.alreadyOff:
        return const ScheduleBlockRelaxResult(
          ok: true,
          message: 'YouTube 전체 차단(타임락)은 이미 꺼져 있어요',
          applied: false,
        );
      case YoutubeTimelockDisableRequestKind.disabledNow:
        await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
        return const ScheduleBlockRelaxResult(
          ok: true,
          message: 'YouTube 전체 차단(타임락)을 껐어요',
          applied: true,
        );
      case YoutubeTimelockDisableRequestKind.pending:
        final min = result.remaining?.inMinutes ?? 15;
        return ScheduleBlockRelaxResult(
          ok: true,
          message: 'YouTube 타임락 끄기 대기 시작 — 약 $min분 후 자동으로 꺼져요',
          startedCountdown: true,
          scheduleId: YoutubeTimelockService.timelockScheduleId,
          relaxAction: ScheduleBlockRelaxAction.timelockOff,
        );
    }
  }
}

enum ScheduleBlockRelaxAction {
  domainsOff,
  isleInAppOff,
  youtubeOff,
  instagramOff,
  scheduleOff,
  timelockOff,
}

class ScheduleBlockRelaxResult {
  const ScheduleBlockRelaxResult({
    required this.ok,
    required this.message,
    this.applied = false,
    this.startedCountdown = false,
    this.needsCountdown = false,
    this.scheduleId,
    this.relaxAction,
  });

  final bool ok;
  final String message;
  final bool applied;
  final bool startedCountdown;
  final bool needsCountdown;
  final String? scheduleId;
  final ScheduleBlockRelaxAction? relaxAction;
}
