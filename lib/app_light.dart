import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'bootstrap/auth_callback_listener.dart';
import 'bootstrap/volt_app_lifecycle.dart';
import 'core/constants/app_build_config.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/env.dart';
import 'core/localization/app_strings.dart';
import 'core/localization/locale_controller.dart';
import 'core/youtube/blocked_channel_sync_listener.dart';
import 'router/app_router_light.dart';
import 'shared/widgets/app_version_badge.dart';

class IsleLightApp extends ConsumerWidget {
  const IsleLightApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterLightProvider);
    final appLocale = ref.watch(appLocaleProvider);

    Widget app = MaterialApp.router(
      title: AppBuildConfig.appTitle,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AppVersionOverlay(lightMode: true, child: child),
      locale: appLocale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: IsleColors.ocean500,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        fontFamilyFallback: const ['Roboto', 'Noto Sans', 'Noto Sans KR'],
      ),
      routerConfig: router,
    );

    app = VoltAppLifecycle(child: app);

    if (Env.isSupabaseConfigured) {
      app = AuthCallbackListener(child: BlockedChannelSyncListener(child: app));
    }

    return app;
  }
}
