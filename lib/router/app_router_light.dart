import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/env.dart';
import '../core/navigation/isle_navigator_key.dart';
import '../features/auth/presentation/login_callback_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/light/presentation/light_blocks_hub_screen.dart';
import '../features/light/presentation/light_settings_screen.dart';
import '../features/settings/presentation/block_schedule_edit_screen.dart';
import '../features/settings/presentation/block_schedules_screen.dart';
import '../features/settings/presentation/schedule_calendar_screen.dart';
import '../features/settings/presentation/blocked_channels_screen.dart';
import '../features/settings/presentation/blocked_videos_screen.dart';
import '../features/settings/presentation/data_backup_screen.dart';
import '../features/settings/presentation/focus_controls_settings_screens.dart';
import '../features/settings/presentation/youtube_filter_settings_screen.dart';
import '../features/youtube/presentation/youtube_browser_screen.dart';
import '../features/youtube/presentation/youtube_login_guide_screen.dart';
import '../core/youtube/models/youtube_focus_video.dart';
import '../features/youtube_focus/presentation/youtube_focus_home_screen.dart';
import '../features/youtube_focus/presentation/youtube_focus_read_first_screen.dart';
import '../features/youtube_focus/presentation/youtube_focus_results_screen.dart';
import '../shared/widgets/isle_bottom_nav_light.dart';
import 'go_router_refresh.dart';
import '../features/auth/providers/auth_provider.dart';

final goRouterLightProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterRefreshStream(ref.watch(authRepoProvider).authStream);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: isleNavigatorKey,
    initialLocation: '/light/youtube',
    refreshListenable: refresh,
    redirect: (context, state) {
      if (!Env.isSupabaseConfigured) return null;
      final user = Supabase.instance.client.auth.currentUser;
      final loc = state.matchedLocation;
      const public = {'/login', '/login-callback'};
      if (user == null && !public.contains(loc)) {
        return null;
      }
      if (user != null && loc == '/login') {
        return '/light/youtube';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen(lightMode: true)),
      GoRoute(
        path: '/login-callback',
        builder: (_, state) => LoginCallbackScreen(uri: state.uri, lightMode: true),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => LightMainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/light/youtube',
              builder: (_, __) => const YoutubeBrowserScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/light/blocks',
              builder: (_, __) => const LightBlocksHubScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/light/schedules',
              builder: (_, __) => const BlockSchedulesScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => BlockScheduleEditScreen(
                    scheduleId: state.pathParameters['id'] ?? '',
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/light/schedule-calendar',
              builder: (_, __) => const ScheduleCalendarScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/light/settings',
              builder: (_, __) => const LightSettingsScreen(),
              routes: [
                GoRoute(path: 'blocked', builder: (_, __) => const BlockedChannelsScreen()),
                GoRoute(path: 'blocked-videos', builder: (_, __) => const BlockedVideosScreen()),
                GoRoute(
                  path: 'youtube-filter',
                  builder: (_, __) => const YoutubeFilterSettingsScreen(),
                ),
                GoRoute(
                  path: 'youtube-limits',
                  builder: (_, __) => const YoutubeLimitsSettingsScreen(),
                ),
                GoRoute(path: 'backup', builder: (_, __) => const DataBackupScreen()),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/youtube/login-guide',
        builder: (_, __) => const YoutubeLoginGuideScreen(),
      ),
      GoRoute(path: '/youtube-focus', builder: (_, __) => const YoutubeFocusHomeScreen()),
      GoRoute(
        path: '/youtube-focus/results',
        builder: (_, state) => YoutubeFocusResultsScreen(
          query: state.uri.queryParameters['q'] ?? '',
        ),
      ),
      GoRoute(
        path: '/youtube-focus/watch/:videoId',
        builder: (_, state) {
          final extra = state.extra;
          if (extra is YoutubeFocusVideo) {
            return YoutubeFocusReadFirstScreen(video: extra);
          }
          final id = state.pathParameters['videoId'] ?? '';
          return YoutubeFocusReadFirstScreen(
            video: YoutubeFocusVideo(videoId: id, title: 'YouTube', channelName: ''),
          );
        },
      ),
      GoRoute(
        path: '/light/youtube-limits',
        builder: (_, __) => const YoutubeLimitsSettingsScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

class LightMainShell extends StatelessWidget {
  const LightMainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: IsleBottomNavLight(
        currentIndex: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
