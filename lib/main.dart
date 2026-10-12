import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import 'app.dart';
import 'bootstrap/isle_bootstrap_gate.dart';
import 'bootstrap/share_intent_bootstrap.dart';
import 'core/constants/app_release_info.dart';
import 'core/constants/env.dart';
import 'core/services/isle_app_log_service.dart';
import 'core/services/isle_debug_log_service.dart';
import 'core/services/isle_draft_autosave_service.dart';
import 'core/services/app_update_audit_service.dart';
import 'core/services/isle_user_defaults.dart';
import 'core/services/trusted_time_guard.dart';
import 'core/ai/ai_config_store.dart';
import 'core/qa/device_qa_store.dart';
import 'core/perf/isle_frame_watchdog.dart';
import 'core/perf/isle_perf_log_service.dart';
import 'core/ai/ai_usage_log_store.dart';
import 'core/ai/api_budget_store.dart';
import 'core/library/engagement_tracker.dart';
import 'core/library/platform_watch_limit_store.dart';
import 'core/usage_budget/usage_budget_pending_policy_service.dart';
import 'core/usage_budget/usage_budget_store.dart';
import 'core/library/interest_pipeline_store.dart';
import 'core/library/personal_library_store.dart';
import 'core/share/shared_playlist_store.dart';
import 'core/insight/insight_portfolio_store.dart';
import 'core/insight/depth_match_service.dart';
import 'core/block_schedule/block_schedule_store.dart';
import 'core/block_schedule/schedule_app_targets_service.dart';
import 'core/block_schedule/schedule_app_targets_store.dart';
import 'core/block_schedule/schedule_pending_target_store.dart';
import 'core/block_schedule/schedule_pending_target_service.dart';
import 'core/block_schedule/app_open_block_trigger_service.dart';
import 'core/block_schedule/schedule_reservation_service.dart';
import 'core/block_schedule/schedule_bundle_usage_store.dart';
import 'core/intervention/app_usage_limit_store.dart';
import 'core/block_schedule/quick_block_service.dart';
import 'core/intervention/external_app_shield_store.dart';
import 'core/intervention/schedule_screen_time_store.dart';
import 'core/block_schedule/url_rules/schedule_rule_store.dart';
import 'core/intervention/website_block_store.dart';
import 'core/safe_browser/safe_browser_history_store.dart';
import 'core/safe_browser/safe_browser_temporary_allow_store.dart';
import 'core/block_schedule/block_schedule_enforcement_service.dart';
import 'core/block_schedule/schedule_notification_service.dart';
import 'core/block_schedule/volt_schedule_boundary_service.dart';
import 'core/intervention/screen_time_persistence_service.dart';
import 'core/platform/ios_screen_time_service.dart';
import 'core/platform/isle_apple_platform.dart';
import 'core/platform/mac_browser_session_service.dart';
import 'core/intervention/browser_youtube_tracking_prefs.dart';
import 'core/youtube/youtube_podcast_listen_store.dart';
import 'core/youtube/youtube_podcast_saved_playlist_store.dart';
import 'core/youtube/youtube_timelock_service.dart';
import 'core/youtube/youtube_usage_lock.dart';
import 'core/youtube/youtube_watch_timer_store.dart';
import 'core/youtube/creative_analytics/creative_analytics_store.dart';
import 'core/youtube/blocked_channel_store.dart';
import 'core/youtube/channel_genre_block_store.dart';
import 'core/youtube/blocked_url_store.dart';
import 'core/ai/block_chat/block_audit_log_store.dart';
import 'core/youtube/content_filter_store.dart';
import 'core/youtube/youtube_block_rules_sync.dart';
import 'core/block/premade_block_pack_auto_sync_service.dart';
import 'core/block/premade_block_pack_removal_service.dart';
import 'core/block/schedule_premade_block_pack_service.dart';
import 'core/block/schedule_premade_pack_store.dart';
import 'core/block/rule_pending_removal_service.dart';
import 'core/block/rule_pending_removal_store.dart';
import 'core/island/island_snapshot_store.dart';
import 'core/island/local_shelf_store.dart';
import 'core/services/isle_checkpoint_service.dart';
import 'core/brunch/brunch_blocked_author_store.dart';
import 'core/feed/feed_boost_store.dart';
import 'core/feed/feed_ingest_store.dart';
import 'core/services/isle_data_migration_service.dart';
import 'core/services/isle_survival_backup_service.dart';
import 'core/platform/isle_web_session_persistence_service.dart';
import 'core/guard/isle_bootstrap_state.dart';
import 'core/guard/isle_startup_guard.dart';
import 'core/social/instagram_following_store.dart';
import 'core/social/isle_social_store.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/focus/kakao_shorts_addiction_store.dart';
import 'core/focus/kakao_android_usage_bridge.dart';
import 'core/block/premade_block_pack_registry.dart';
import 'core/safety/adult_protection_service.dart';
import 'bootstrap/dev_api_key_seeder.dart';

Future<void> _safe(String label, Future<void> Function() fn) async {
  try {
    await fn();
  } catch (e, st) {
    debugPrint('Bootstrap $label failed: $e\n$st');
    IsleAppLogService.log('Bootstrap $label failed: $e',
        level: IsleLogLevel.warn);
    if (label == 'cache' || label == 'supabase') {
      IsleBootstrapState.markFailure(label);
    }
  }
}

Future<void> _bootstrap() async {
  try {
    await IsleDebugLogService.bootstrap();
    IsleDebugLogService.installGlobalHandlers();
  } catch (e, st) {
    debugPrint('IsleDebugLogService bootstrap failed: $e\n$st');
  }
  await _safe('release-info', AppReleaseInfo.initialize);
  IsleAppLogService.log('App launch ${AppReleaseInfo.label}');
  IsleFrameWatchdog.install();
  unawaited(IslePerfLogService.ensureReady());

  await _safe('firebase', FirebaseBootstrap.initializeIfSupported);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  try {
    await Hive.initFlutter();
  } catch (e, st) {
    IsleBootstrapState.markFailure('hive_init');
    debugPrint('Hive.initFlutter failed: $e\n$st');
    IsleAppLogService.log('Hive.initFlutter failed: $e',
        level: IsleLogLevel.error);
  }
  await _safe('cache', () => Hive.openBox<String>('isle_cache'));
  await _safe('4vpn_preset_manifest', PremadeBlockPackRegistry.ensureLoaded);
  await _safe(
      'adult_protection_migrate', AdultProtectionService.migrateIfNeeded);
  await _safe('drafts', IsleDraftAutosaveService.ensureOpen);
  await _safe('blocked', BlockedChannelStore.ensureOpen);
  await _safe('genre', ChannelGenreBlockStore.ensureOpen);
  await _safe('filter', ContentFilterStore.ensureOpen);
  await _safe('filter_sanitize', ContentFilterStore.ensureKeywordsSanitized);
  await _safe('blocked_urls', BlockedUrlStore.ensureOpen);
  await _safe('website_blocks', WebsiteBlockStore.ensureOpen);
  await _safe('block_audit_log', BlockAuditLogStore.ensureOpen);
  await _safe('block_audit_log_prune', BlockAuditLogStore.pruneNow);
  await _safe('rule_pending_removals', RulePendingRemovalStore.ensureOpen);
  RulePendingRemovalService.registerHandlers(
    removeKeyword: (key) async {
      final list = ContentFilterStore.loadKeywords()
        ..removeWhere((k) => k == key);
      await ContentFilterStore.saveKeywords(list);
    },
    removeUrl: (canonical) => BlockedUrlStore.remove(canonical),
    removePremadePack: (key) async {
      if (SchedulePremadePackService.isSchedulePendingKey(key)) {
        final scheduleId =
            SchedulePremadePackService.parseScheduleIdFromPendingKey(key);
        final packId =
            SchedulePremadePackService.parsePackIdFromPendingKey(key);
        if (scheduleId != null && packId != null) {
          await SchedulePremadePackService.unlinkImmediate(
            scheduleId: scheduleId,
            packId: packId,
          );
        }
      } else {
        await PremadeBlockPackRemovalService.executeScheduledRemoval(key);
      }
    },
    afterRemoval: YoutubeBlockRulesSync.scheduleExport,
  );
  await _safe('rule_pending_process', RulePendingRemovalService.processDue);
  await _safe('premade_pack_auto_sync',
      () => PremadeBlockPackAutoSyncService.syncAllApplied());
  await _safe('library', PersonalLibraryStore.ensureOpen);
  await _safe('playlists', SharedPlaylistStore.ensureOpen);
  await _safe('insight', InsightPortfolioStore.ensureOpen);
  await _safe('depth_peers', DepthMatchService.ensureSeedPeers);
  await _safe('engagement', EngagementTracker.ensureOpen);
  await _safe('watch', YoutubeWatchTimerStore.ensureOpen);
  await _safe('usage_budget', UsageBudgetStore.ensureOpen);
  await _safe('podcast_listen', YoutubePodcastListenStore.ensureOpen);
  await _safe('podcast_playlists', YoutubePodcastSavedPlaylistStore.ensureOpen);
  await _safe('yt_creative', CreativeAnalyticsStore.ensureOpen);
  await _safe('platform_watch', PlatformWatchLimitStore.ensureOpen);
  await _safe('schedule', BlockScheduleStore.ensureOpen);
  await _safe('schedule_st', ScheduleScreenTimeStore.ensureOpen);
  await _safe('schedule_st_bundle_migration',
      ScheduleAppTargetsService.migrateLegacyScreenTimeSelectionsIfNeeded);
  await _safe('schedule_targets', () async {
    await ScheduleAppTargetsStore.ensureOpen();
    await ScheduleBundleUsageStore.ensureOpen();
    await SchedulePendingTargetStore.ensureOpen();
    // 기기 시계를 앞으로 돌려 타임락을 우회하는 걸 막으려면, 아래 대기 판정들
    // (processDue 등)이 돌기 *전에* 네트워크로 실제 시각을 먼저 확인해야
    // 한다(2026-07-15 사용자 요청, cage에서 먼저 구현 후 이식). 콜드 부팅
    // 경로라 첫 화면이 너무 늦어지지 않게 refresh() 자체에 짧은 타임아웃이
    // 걸려 있다.
    await TrustedTimeGuard.refresh();
    await SchedulePendingTargetService.processDue();
    await UsageBudgetPendingPolicyService.processDue();
    await YoutubeTimelockService.processPendingDisable();
    await YoutubeUsageLock.processPendingDisable();
    // 예약 스케줄(scheduled_reservation, 2026-07-20 신설) 자동 활성화/종료 —
    // TrustedTimeGuard.refresh() 뒤에 돌려야 기기 시계 조작으로 예약 기간을
    // 앞당기거나 늦추는 걸 막는다.
    await ScheduleReservationService.processDue();
    // 앱 켠 지 N분 트리거(app_open_block_trigger, 2026-07-20 신설) — 콜드
    // 부팅도 "앱을 여는 순간"이니 여기서 같이 체크한다.
    await AppOpenBlockTriggerService.maybeTriggerOnAppOpen();
  });
  // "최소한의 안전 라인" 자동 심기(2026-07-16 사용자 요청)는 여기서 동기로
  // 기다리지 않는다 — ScheduleAppTargetsService.saveAndSync가 내부적으로
  // syncPlatformEnforcement(네이티브 Screen Time 호출)를 스케줄 3개당 한 번씩
  // 부른다. 부팅 시퀀스 한복판(UI가 아직 안 뜬 시점)에서 이걸 기다리면, 첫
  // 실행 때 기기의 Screen Time 인증 절차와 얽혀 부팅 자체가 영영 안 끝나고
  // "무한 로딩 화면"으로 멈추는 실사용 버그가 났다(2026-[REDACTED] 실기기 확인).
  // 무거운 OS 동기화는 원래도 UI가 뜬 뒤 IsleDeferredOsSyncService에서만
  // 하기로 정해둔 규칙이 있었는데, 이 seeder가 그 규칙을 어겼던 것 — 같은
  // 규칙을 따르게 옮긴다(_bootstrap.dart의 IsleDeferredOsSyncService에서 호출).
  // 업데이트 후 isle_cache 가 초기화되면 yt_schedule_lock_on 이 'false' 로 리셋됨.
  // 스케줄 데이터가 남아 있으면 마스터 스위치를 복구한다.
  await _safe('schedule_master_recovery', () async {
    if (BlockScheduleStore.loadAll().isNotEmpty &&
        !IsleUserDefaults.youtubeScheduleLockEnabled) {
      await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);
      IsleAppLogService.log(
          'schedule_master_recovery: re-enabled master switch');
    }
  });
  // 위 recovery가 손보는 것과 같은 부류의 문제("업데이트 후 캐시가 초기화되면
  // 마스터 스위치가 리셋됨")를 감사 로그에도 남긴다 — 이번엔 스위치가 아니라
  // 스케줄 개수 자체가 급감했는지까지 비교해, 다음에 리셋을 겪으면 이게
  // 업데이트 때문이었는지 챗 명령 때문이었는지 로그로 구분할 수 있게 한다.
  await _safe('app_update_audit', AppUpdateAuditService.checkAndRecord);
  if (IsleApplePlatform.isScreenTimeHost) {
    await _safe('yt_os_web_unblock', () async {
      await IosScreenTimeService.ensureIsleYoutubeWebViewUnblocked();
      if (BrowserYoutubeTrackingPrefs.osWebBlockApplied) {
        await BrowserYoutubeTrackingPrefs.setOsWebBlockApplied(false);
      }
    });
  }
  await _safe('quick_block', QuickBlockService.ensureOpen);
  await _safe('app_shield', ExternalAppShieldStore.ensureOpen);
  await _safe('schedule_rules', ScheduleRuleStore.ensureOpen);
  await _safe('schedule_premade_packs', SchedulePremadePackStore.ensureOpen);
  await _safe('safe_browser_allow', SafeBrowserTemporaryAllowStore.ensureOpen);
  await _safe('safe_browser_history', SafeBrowserHistoryStore.ensureOpen);
  await _safe(
      'website_blocks_sanitize', WebsiteBlockStore.ensureDomainsSanitized);
  await _safe('kakao_shorts', KakaoShortsAddictionStore.ensureOpen);
  await _safe('kakao_android', KakaoAndroidUsageBridge.ensureListening);
  await _safe('app_limits', AppUsageLimitStore.ensureOpen);
  // OS 앱 한도·Screen Time 동기화는 UI 표시 후 IsleDeferredOsSyncService에서 1회만
  await _safe('volt', VoltScheduleBoundaryService.reconcileLocksOnly);
  await _safe('schedule_notif', ScheduleNotificationService.rescheduleAll);
  if (Platform.isMacOS) {
    await _safe('mac_enforce', () async {
      await BlockScheduleEnforcementService.syncPlatformEnforcement(
          force: true);
      await MacBrowserSessionService.startMonitoring();
    });
  }
  if (Platform.isAndroid) {
    await _safe('android_enforce', () async {
      await BlockScheduleEnforcementService.syncPlatformEnforcement(
          force: true);
    });
  }
  await _safe('budget', ApiBudgetStore.ensureOpen);
  await _safe('ai', AiConfigStore.ensureOpen);
  await _safe('dev_key', DevApiKeySeeder.seedIfEmpty);
  await _safe('device_qa', DeviceQaStore.ensureOpen);
  await _safe('ai_log', AiUsageLogStore.ensureOpen);
  await _safe('pipeline', InterestPipelineStore.ensureOpen);
  await _safe('island', IslandSnapshotStore.ensureOpen);
  await _safe('local_shelves', LocalShelfStore.ensureOpen);
  await _safe('feed', FeedIngestStore.ensureOpen);
  await _safe('boost', FeedBoostStore.ensureOpen);
  await _safe('brunch', BrunchBlockedAuthorStore.ensureOpen);
  await _safe('social', IsleSocialStore.ensureOpen);
  await _safe('instagram', InstagramFollowingStore.ensureOpen);
  await _safe('data_migration', IsleDataMigrationService.runAfterStoresOpen);
  await _safe(
      'web_session', IsleWebSessionPersistenceService.restoreOnBootstrap);
  await _safe('survival', IsleSurvivalBackupService.bootstrapOnLaunch);
  await _safe('screen_time_persist',
      ScreenTimePersistenceService.bootstrapAfterDataLoad);
  await _safe(
      'checkpoint', IsleCheckpointService.restoreFromCheckpointIfLocalEmpty);
  IsleCheckpointService.startPeriodicCheckpoint();
  await _safe('defaults', IsleUserDefaults.applyCommanderDefaults);
  await _safe('supabase', () async {
    if (!Env.isSupabaseConfigured) return;
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  });
}

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      IsleStartupGuard.install();

      final isIosSimulator = Platform.isIOS &&
          (Platform.environment.containsKey('SIMULATOR_UDID') ||
              Platform.environment.containsKey('SIMULATOR_DEVICE_NAME'));
      final enableShareBootstrap =
          (Platform.isIOS && !isIosSimulator) || Platform.isAndroid;

      Future<void> bootstrap() async {
        try {
          await _bootstrap();
        } catch (e, st) {
          IsleBootstrapState.markFailure('bootstrap_fatal');
          debugPrint('Bootstrap fatal: $e\n$st');
          unawaited(
            IsleDebugLogService.recordCrash(
              kind: 'bootstrap_fatal',
              message: e.toString(),
              stack: st,
            ),
          );
          // rethrow 금지 — 게이트가 복구 화면을 보여 주고 앱은 열리게
        }
      }

      final appChild = enableShareBootstrap
          ? const ShareIntentBootstrap(child: IsleApp())
          : const IsleApp();

      runApp(
        ProviderScope(
          child: IsleBootstrapGate(
            bootstrap: bootstrap,
            child: appChild,
          ),
        ),
      );
    },
    (error, stack) {
      unawaited(
        IsleDebugLogService.recordCrash(
          kind: 'zone_error',
          message: error.toString(),
          stack: stack,
        ),
      );
    },
  );
}
