import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_build_config.dart';
import 'router/app_router_youtube_focus.dart';
import 'shared/widgets/app_version_badge.dart';

/// 유튜브 몰입 MVP 전용 앱 셸 — `main_youtube_focus.dart`
class IsleYoutubeFocusApp extends ConsumerWidget {
  const IsleYoutubeFocusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterYoutubeFocusProvider);

    return MaterialApp.router(
      title: AppBuildConfig.appTitle,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AppVersionOverlay(child: child ?? const SizedBox.shrink()),
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: router,
    );
  }
}
