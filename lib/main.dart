import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import 'app.dart';
import 'bootstrap/share_intent_bootstrap.dart';
import 'core/constants/app_release_info.dart';
import 'core/constants/env.dart';
import 'core/services/isle_app_log_service.dart';
import 'core/services/isle_debug_log_service.dart';
import 'core/services/isle_draft_autosave_service.dart';
import 'core/services/isle_user_defaults.dart';
import 'core/ai/ai_config_store.dart';
import 'core/qa/device_qa_store.dart';
import 'core/perf/isle_frame_watchdog.dart';
import 'core/perf/isle_perf_log_service.dart';
import 'core/ai/ai_usage_log_store.dart';
import 'core/ai/api_budget_store.dart';
import 'core/library/engagement_tracker.dart';
import 'core/library/platform_watch_limit_store.dart';
import 'core/library/interest_pipeline_store.dart';
import 'core/library/personal_library_store.dart';
import 'core/share/shared_playlist_store.dart';
import 'core/insight/insight_portfolio_store.dart';
import 'core/insight/depth_match_service.dart';
import 'core/block_schedule/block_schedule_store.dart';
import 'core/block_schedule/schedule_app_targets_store.dart';
import 'core/block_schedule/schedule_bundle_usage_store.dart';
import 'core/intervention/app_usage_limit_store.dart';
import 'core/block_schedule/schedule_app_limit_sync_service.dart';
import 'core/block_schedule/quick_block_service.dart';
import 'core/intervention/external_app_shield_store.dart';
import 'core/intervention/schedule_screen_time_store.dart';
import 'core/block_schedule/url_rules/schedule_rule_store.dart';
import 'core/intervention/website_block_store.dart';
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
import 'core/youtube/youtube_watch_timer_store.dart';
import 'core/youtube/creative_analytics/creative_analytics_store.dart';
import 'core/youtube/blocked_channel_store.dart';
import 'core/youtube/channel_genre_block_store.dart';
import 'core/youtube/blocked_url_store.dart';
import 'core/youtube/content_filter_store.dart';
import 'core/youtube/youtube_block_rules_sync.dart';
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
import 'core/guard/isle_bootstrap_state.dart';
import 'core/guard/isle_startup_guard.dart';
import 'core/social/instagram_following_store.dart';
import 'core/social/isle_social_store.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/focus/kakao_shorts_addiction_store.dart';
import 'core/focus/kakao_android_usage_bridge.dart';

Future<void> _safe(String label, Future<void> Function() fn) async {
  try {
    await fn();
  } catch (e, st) {
    debugPrint('Bootstrap $label failed: $e\n$st');
    IsleAppLogService.log('Bootstrap $label failed: $e', level: IsleLogLevel.warn);
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
    IsleAppLogService.log('Hive.initFlutter failed: $e', level: IsleLogLevel.error);
  }
  await _safe('cache', () => Hive.openBox<String>('isle_cache'));
  await _safe('drafts', IsleDraftAutosaveService.ensureOpen);
  await _safe('blocked', BlockedChannelStore.ensureOpen);
  await _safe('genre', ChannelGenreBlockStore.ensureOpen);
  await _safe('filter', ContentFilterStore.ensureOpen);
  await _safe('filter_sanitize', ContentFilterStore.ensureKeywordsSanitized);
  await _safe('blocked_urls', BlockedUrlStore.ensureOpen);
  await _safe('rule_pending_removals', RulePendingRemovalStore.ensureOpen);
  RulePendingRemovalService.registerHandlers(
    removeKeyword: (key) async {
      final list = ContentFilterStore.loadKeywords()..removeWhere((k) => k == key);
      await ContentFilterStore.saveKeywords(list);
    },
    removeUrl: (canonical) => BlockedUrlStore.remove(canonical),
    afterRemoval: YoutubeBlockRulesSync.scheduleExport,
  );
  await _safe('rule_pending_process', RulePendingRemovalService.processDue);
  await _safe('library', PersonalLibraryStore.ensureOpen);
  await _safe('playlists', SharedPlaylistStore.ensureOpen);
  await _safe('insight', InsightPortfolioStore.ensureOpen);
  await _safe('depth_peers', DepthMatchService.ensureSeedPeers);
  await _safe('engagement', EngagementTracker.ensureOpen);
  await _safe('watch', YoutubeWatchTimerStore.ensureOpen);
  await _safe('podcast_listen', YoutubePodcastListenStore.ensureOpen);
  await _safe('podcast_playlists', YoutubePodcastSavedPlaylistStore.ensureOpen);
  await _safe('yt_creative', CreativeAnalyticsStore.ensureOpen);
  await _safe('platform_watch', PlatformWatchLimitStore.ensureOpen);
  await _safe('schedule', BlockScheduleStore.ensureOpen);
  await _safe('schedule_st', ScheduleScreenTimeStore.ensureOpen);
  await _safe('schedule_targets', () async {
    await ScheduleAppTargetsStore.ensureOpen();
    await ScheduleBundleUsageStore.ensureOpen();
  });
  // 업데이트 후 isle_cache 가 초기화되면 yt_schedule_lock_on 이 'false' 로 리셋됨.
  // 스케줄 데이터가 남아 있으면 마스터 스위치를 복구한다.
  await _safe('schedule_master_recovery', () async {
    if (BlockScheduleStore.loadAll().isNotEmpty &&
        !IsleUserDefaults.youtubeScheduleLockEnabled) {
      await IsleUserDefaults.setYoutubeScheduleLockEnabled(true);
      IsleAppLogService.log('schedule_master_recovery: re-enabled master switch');
    }
  });
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
  await _safe('website_blocks', WebsiteBlockStore.ensureOpen);
  await _safe('website_blocks_sanitize', WebsiteBlockStore.ensureDomainsSanitized);
  await _safe('kakao_shorts', KakaoShortsAddictionStore.ensureOpen);
  await _safe('kakao_android', KakaoAndroidUsageBridge.ensureListening);
  await _safe('app_limits', AppUsageLimitStore.ensureOpen);
  await _safe('app_limits_sync', ScheduleAppLimitSyncService.syncAll);
  await _safe('volt', VoltScheduleBoundaryService.reconcileAfterResume);
  await _safe('notif_perm', () async {
    // 첫 실행 시 한 번만 알림 권한 요청 — 스케줄이 없어도 리마인더를 받을 수 있게.
    if (IsleUserDefaults.notificationPermissionRequested) return;
    final granted = await ScheduleNotificationService.requestPermission();
    await IsleUserDefaults.setNotificationPermissionRequested(true);
    IsleAppLogService.log('startup notif permission granted=$granted');
  });
  await _safe('schedule_notif', ScheduleNotificationService.rescheduleAll);
  if (Platform.isMacOS) {
    await _safe('mac_enforce', () async {
      await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
      await MacBrowserSessionService.startMonitoring();
    });
  }
  if (Platform.isAndroid) {
    await _safe('android_enforce', () async {
      await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
    });
  }
  await _safe('budget', ApiBudgetStore.ensureOpen);
  await _safe('ai', AiConfigStore.ensureOpen);
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
  await _safe('survival', IsleSurvivalBackupService.bootstrapOnLaunch);
  await _safe('screen_time_persist', ScreenTimePersistenceService.bootstrapAfterDataLoad);
  await _safe('checkpoint', IsleCheckpointService.restoreFromCheckpointIfLocalEmpty);
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
  WidgetsFlutterBinding.ensureInitialized();
  IsleStartupGuard.install();
  runZonedGuarded(
    () async {
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
      }

      final isIosSimulator = Platform.isIOS &&
          (Platform.environment.containsKey('SIMULATOR_UDID') ||
              Platform.environment.containsKey('SIMULATOR_DEVICE_NAME'));
      final enableShareBootstrap =
          (Platform.isIOS && !isIosSimulator) || Platform.isAndroid;

      runApp(
        ProviderScope(
          child: enableShareBootstrap
              ? const ShareIntentBootstrap(child: IsleApp())
              : const IsleApp(),
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
