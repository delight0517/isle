import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_youtube_focus.dart';
import 'core/constants/app_build_config.dart';
import 'core/constants/app_release_info.dart';
import 'core/services/isle_app_log_service.dart';

/// iOS/Android — 유튜브 몰입 MVP 단독 진입점 (기존 Isle main.dart 와 별도)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppBuildConfig.isYoutubeFocusBuild = true;

  IsleAppLogService.installGlobalHandlers();
  IsleAppLogService.log('Isle YouTube Focus launch ${AppReleaseInfo.label}');

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await Hive.initFlutter();
  await Hive.openBox<String>('isle_cache');

  runApp(const ProviderScope(child: IsleYoutubeFocusApp()));
}
