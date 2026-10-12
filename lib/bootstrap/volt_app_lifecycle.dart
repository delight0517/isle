import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/ai/block_chat/block_chat_executor.dart';
import '../core/block_schedule/schedule_block_relax_service.dart';
import '../core/block_schedule/schedule_pending_target_service.dart';
import '../core/block_schedule/app_open_block_trigger_service.dart';
import '../core/block_schedule/schedule_reservation_service.dart';
import '../core/block_schedule/pomodoro_wake_lock_sync.dart';
import '../core/block_schedule/volt_schedule_boundary_service.dart';
import '../core/focus/kakao_pomodoro_break_enforcement.dart';
import '../core/block/premade_block_pack_auto_sync_service.dart';
import '../core/block/rule_pending_removal_service.dart';
import '../core/feed/feed_ingest_service.dart';
import '../core/library/youtube_account_sync_service.dart';
import '../core/share/shared_playlist_cc_service.dart';
import '../core/usage_budget/usage_budget_pending_policy_service.dart';
import '../core/platform/ios_rules_export_service.dart';
import '../core/platform/ios_screen_time_service.dart';
import '../core/platform/isle_apple_platform.dart';
import '../core/services/isle_debug_log_service.dart';
import '../core/services/isle_draft_autosave_service.dart';
import '../core/services/isle_checkpoint_service.dart';
import '../core/services/isle_survival_backup_service.dart';
import '../core/platform/isle_web_session_persistence_service.dart';
import '../core/services/trusted_time_guard.dart';
import '../core/services/volt_lifecycle_service.dart';
import '../core/youtube/youtube_timelock_migration.dart';
import '../core/youtube/youtube_timelock_service.dart';
import '../core/youtube/youtube_usage_lock.dart';
import '../core/youtube/youtube_webview_energy.dart';

/// [Volt] 앱 활성/비활성 시 타임스탬프만 기록 (백그라운드 연산 없음)
class VoltAppLifecycle extends StatefulWidget {
  const VoltAppLifecycle({super.key, required this.child});

  final Widget child;

  @override
  State<VoltAppLifecycle> createState() => _VoltAppLifecycleState();
}

class _VoltAppLifecycleState extends State<VoltAppLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        VoltLifecycleService.onAppPaused();
        unawaited(IsleDraftAutosaveService.flushAll());
        unawaited(IsleSurvivalBackupService.syncNow());
        unawaited(IsleWebSessionPersistenceService.saveNow());
        unawaited(IsleCheckpointService.snapshot());
        unawaited(IsleDebugLogService.markCleanShutdown());
        unawaited(VoltScheduleBoundaryService.recordPauseSnapshot());
        YoutubeWebviewEnergy.pauseAll();
      case AppLifecycleState.resumed:
        VoltLifecycleService.onAppResumed();
        YoutubeWebviewEnergy.resumeAll();
        unawaited(VoltScheduleBoundaryService.reconcileAfterResume());
        unawaited(ScheduleBlockRelaxService.tryApplyPendingRelax());
        unawaited(BlockChatExecutor.applyPendingFullResetIfDue());
        // 기기 시계를 앞으로 돌려 타임락을 우회하는 걸 막으려면, 아래 대기
        // 판정들이 돌기 *전에* 네트워크로 실제 시각을 먼저 확인해야 한다
        // (2026-07-15 사용자 요청).
        unawaited(TrustedTimeGuard.refresh().then((_) async {
          await SchedulePendingTargetService.processDue();
          await UsageBudgetPendingPolicyService.processDue();
          await YoutubeTimelockService.processPendingDisable();
          await YoutubeUsageLock.processPendingDisable();
          await ScheduleReservationService.processDue();
          // Auto Pomodoro's confirmed wake event is read only after trusted
          // time is refreshed; the lock expiry remains anchored to source wakeAt.
          await PomodoroWakeLockSync.syncOnResume();
          // 앱 켠 지 N분 트리거(2026-07-20 신설) — 백그라운드→포그라운드
          // 복귀도 "앱을 여는 순간"으로 취급한다(하루 1회 가드는 서비스
          // 내부에서 처리).
          await AppOpenBlockTriggerService.maybeTriggerOnAppOpen();
        }));
        unawaited(YoutubeTimelockMigration.syncTargetsIfNeeded());
        unawaited(KakaoPomodoroBreakEnforcement.syncOnResume());
        unawaited(IsleSurvivalBackupService.syncNow());
        unawaited(FeedIngestService.refreshIfStale());
        unawaited(RulePendingRemovalService.processDue());
        unawaited(PremadeBlockPackAutoSyncService.syncAllApplied(silent: true));
        unawaited(YoutubeAccountSyncService.refreshIfStale());
        unawaited(SharedPlaylistCcService.refreshIfStale());
        // 예전 버전이 남긴 OS youtube 차단이 다시 적용됐을 수 있어 재해제 (내부 isSupported 게이트).
        unawaited(IosScreenTimeService.ensureIsleYoutubeWebViewUnblocked());
        if (IsleApplePlatform.isScreenTimeHost) {
          unawaited(IosRulesExportService.exportNow());
        }
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
