import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_release_info.dart';
import 'core/localization/app_strings.dart';
import 'core/localization/isle_locale_typography.dart';
import 'core/localization/locale_controller.dart';
import 'bootstrap/auth_callback_listener.dart';
import 'bootstrap/youtube_deep_link_bootstrap.dart';
import 'bootstrap/volt_app_lifecycle.dart';
import 'core/youtube/blocked_channel_sync_listener.dart';
import 'router/app_router.dart';
import 'shared/widgets/isle_heavy_work_overlay.dart';
import 'shared/widgets/app_version_badge.dart';
import 'shared/widgets/bootstrap_degraded_banner.dart';
import 'shared/widgets/ios_internal_schedule_lock_overlay.dart';

class IsleApp extends ConsumerWidget {
  const IsleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final appLocale = ref.watch(appLocaleProvider);
    final localeCode = appLocale?.languageCode ?? 'ko';
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: IsleColors.ocean500,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
      fontFamilyFallback: const [
        'SF Pro Text',
        'Noto Sans',
        'Noto Sans KR',
        'Noto Sans Hebrew',
        'Noto Sans JP',
        'Noto Sans SC',
      ],
    );
    return VoltAppLifecycle(
      child: YoutubeDeepLinkBootstrap(
        child: AuthCallbackListener(
          child: BlockedChannelSyncListener(
            child: MaterialApp.router(
      title: AppReleaseInfo.appName,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final dir = IsleLocaleTypography.textDirectionFor(
          Localizations.localeOf(context).languageCode,
        );
        return Directionality(
          textDirection: dir,
          child: AppVersionOverlay(
            child: IsleHeavyWorkOverlayHost(
              child: BootstrapDegradedBanner(
                child: IosScheduleLockOverlayHost(child: child ?? const SizedBox.shrink()),
              ),
            ),
          ),
        );
      },
      locale: appLocale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: IsleLocaleTypography.applyToTheme(baseTheme, appLocale ?? Locale(localeCode)).copyWith(
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          insetPadding: EdgeInsets.fromLTRB(16, 0, 16, 112),
        ),
      ),
      routerConfig: router,
            ),
          ),
        ),
      ),
    );
  }
}
