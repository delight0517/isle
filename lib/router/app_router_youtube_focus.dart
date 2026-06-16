import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation/isle_navigator_key.dart';
import '../core/youtube/models/youtube_focus_video.dart';
import '../features/settings/presentation/app_log_screen.dart';
import '../features/settings/presentation/block_schedule_edit_screen.dart';
import '../features/settings/presentation/block_schedules_screen.dart';
import '../features/settings/presentation/data_backup_screen.dart';
import '../features/settings/presentation/debugger_screen.dart';
import '../features/settings/presentation/focus_controls_settings_screens.dart';
import '../features/settings/presentation/android_system_block_screen.dart';
import '../features/settings/presentation/safari_youtube_os_block_screen.dart';
import '../features/youtube_focus/presentation/youtube_focus_home_screen.dart';
import '../features/youtube_focus/presentation/youtube_focus_more_screen.dart';
import '../features/youtube_focus/presentation/youtube_focus_read_first_screen.dart';
import '../features/youtube_focus/presentation/youtube_focus_results_screen.dart';

final goRouterYoutubeFocusProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: isleNavigatorKey,
    initialLocation: '/youtube-focus',
    routes: [
      GoRoute(
        path: '/youtube-focus',
        builder: (_, __) => const YoutubeFocusHomeScreen(standalone: true),
      ),
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
            video: YoutubeFocusVideo(
              videoId: id,
              title: 'YouTube',
              channelName: '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/youtube-focus/more',
        builder: (_, __) => const YoutubeFocusMoreScreen(),
        routes: [
          GoRoute(
            path: 'safari-youtube-os',
            builder: (_, __) => const SafariYoutubeOsBlockScreen(),
          ),
          GoRoute(
            path: 'android-system-block',
            builder: (_, __) => const AndroidSystemBlockScreen(),
          ),
          GoRoute(
            path: 'schedules',
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
            path: 'youtube-limits',
            builder: (_, __) => const YoutubeLimitsSettingsScreen(),
          ),
          GoRoute(
            path: 'app-log',
            builder: (_, __) => const AppLogScreen(),
          ),
          GoRoute(
            path: 'backup',
            builder: (_, __) => const DataBackupScreen(),
          ),
          GoRoute(
            path: 'debugger',
            builder: (_, __) => const DebuggerScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
