import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_light.dart';
import 'core/constants/app_build_config.dart';
import 'core/constants/app_release_info.dart';
import 'core/constants/env.dart';
import 'core/services/isle_app_log_service.dart';
import 'core/services/isle_survival_backup_service.dart';
import 'core/services/isle_user_defaults.dart';
import 'core/block_schedule/block_schedule_store.dart';
import 'core/block_schedule/volt_schedule_boundary_service.dart';
import 'core/youtube/youtube_watch_timer_store.dart';
import 'core/youtube/blocked_channel_store.dart';
import 'core/youtube/content_filter_store.dart';

/// Android Light — 유튜브·차단·스케줄만 (AI·피드·섬 없음)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppBuildConfig.isLightBuild = true;

  IsleAppLogService.installGlobalHandlers();
  IsleAppLogService.log('Isle Light launch ${AppReleaseInfo.lightLabel}');

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await Hive.initFlutter();
  await Hive.openBox<String>('isle_cache');
  await BlockedChannelStore.ensureOpen();
  await ContentFilterStore.ensureOpen();
  await BlockScheduleStore.ensureOpen();
  await YoutubeWatchTimerStore.ensureOpen();
  await VoltScheduleBoundaryService.reconcileAfterResume();
  await IsleSurvivalBackupService.bootstrapOnLaunch();
  await IsleUserDefaults.applyCommanderDefaults();

  if (Env.isSupabaseConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: IsleLightApp()));
}
