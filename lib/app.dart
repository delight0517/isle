import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_release_info.dart';
import 'core/localization/app_strings.dart';
import 'core/localization/app_locale_policy.dart';
import 'core/localization/isle_locale_typography.dart';
import 'core/localization/locale_controller.dart';
import 'bootstrap/auth_callback_listener.dart';
import 'bootstrap/youtube_deep_link_bootstrap.dart';
import 'bootstrap/volt_app_lifecycle.dart';
import 'bootstrap/wdm_app_update_bootstrap.dart';
import 'core/youtube/blocked_channel_sync_listener.dart';
import 'router/app_router.dart';
import 'shared/widgets/isle_heavy_work_overlay.dart';
import 'shared/widgets/app_version_badge.dart';
import 'shared/widgets/bootstrap_degraded_banner.dart';

class IsleApp extends ConsumerWidget {
  const IsleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final appLocale = ref.watch(appLocaleProvider);
    final localeCode = appLocale?.languageCode ?? 'ko';
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: IsleColors.purple700,
        primary: IsleColors.purple700,
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
      child: WdmAppUpdateBootstrap(
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
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
      // 한국어 우선 제품(CLAUDE.md §1·§6.5). 사용자가 언어를 명시적으로 고르기
      // 전까지는 기기 로케일(영어 등)을 따르지 않고 한국어로 고정한다 — 그렇지
      // 않으면 영어 기기에서 스케줄 등 화면이 영어로 떠 가독성이 무너진다.
      locale: appLocale ?? const Locale(AppLocalePolicy.defaultCode),
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
      ),
    );
  }
}
