import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/block_schedule/volt_schedule_boundary_service.dart';
import '../core/focus/kakao_pomodoro_break_enforcement.dart';
import '../core/block/rule_pending_removal_service.dart';
import '../core/feed/feed_ingest_service.dart';
import '../core/library/youtube_account_sync_service.dart';
import '../core/share/shared_playlist_cc_service.dart';
import '../core/platform/ios_rules_export_service.dart';
import '../core/platform/ios_screen_time_service.dart';
import '../core/platform/isle_apple_platform.dart';
import '../core/services/isle_debug_log_service.dart';
import '../core/services/isle_draft_autosave_service.dart';
import '../core/services/isle_checkpoint_service.dart';
import '../core/services/isle_survival_backup_service.dart';
import '../core/services/volt_lifecycle_service.dart';
import '../core/youtube/youtube_webview_energy.dart';

/// [Volt] 앱 활성/비활성 시 타임스탬프만 기록 (백그라운드 연산 없음)
class VoltAppLifecycle extends StatefulWidget {
  const VoltAppLifecycle({super.key, required this.child});

  final Widget child;

  @override
  State<VoltAppLifecycle> createState() => _VoltAppLifecycleState();
}

class _VoltAppLifecycleState extends State<VoltAppLifecycle> with WidgetsBindingObserver {
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
        unawaited(IsleCheckpointService.snapshot());
        unawaited(IsleDebugLogService.markCleanShutdown());
        unawaited(VoltScheduleBoundaryService.recordPauseSnapshot());
        YoutubeWebviewEnergy.pauseAll();
      case AppLifecycleState.resumed:
        VoltLifecycleService.onAppResumed();
        YoutubeWebviewEnergy.resumeAll();
        unawaited(VoltScheduleBoundaryService.reconcileAfterResume());
        unawaited(KakaoPomodoroBreakEnforcement.syncOnResume());
        unawaited(IsleSurvivalBackupService.syncNow());
        unawaited(FeedIngestService.refreshIfStale());
        unawaited(RulePendingRemovalService.processDue());
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
