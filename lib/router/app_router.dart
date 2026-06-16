import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/env.dart';
import '../core/focus/isle_product_focus.dart';
import '../core/services/pending_share_url_store.dart';
import '../core/navigation/isle_navigator_key.dart';
import '../features/archive/presentation/archive_input_screen.dart';
import '../features/archive/presentation/content_viewer_screen.dart';
import '../features/auth/presentation/login_callback_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/onboarding/onboarding_screen.dart';
import '../features/ai/presentation/ai_hub_screen.dart';
import '../features/ai/presentation/block_chat_screen.dart';
import '../features/ai/presentation/ai_usage_log_screen.dart';
import '../features/guide/presentation/android_visual_tutorial_screen.dart';
import '../features/guide/presentation/app_tour_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/explore/presentation/chat_gate_screen.dart';
import '../features/explore/presentation/request_inbox_screen.dart';
import '../features/explore/presentation/explore_screen.dart';
import '../features/focus/presentation/focus_hub_screen.dart';
import '../features/focus/presentation/pomodoro_break_screen.dart';
import '../features/home/presentation/block_home_screen.dart';
import '../features/home/presentation/share_home_screen.dart';
import '../features/home/presentation/share_playlist_screen.dart';
import '../features/home/presentation/share_quick_save_screen.dart';
import '../features/feed/presentation/feed_screen.dart';
import '../features/island/presentation/island_screen.dart';
import '../features/island/presentation/other_islands_browser_screen.dart';
import '../features/settings/presentation/platform_usage_stats_screen.dart';
import '../features/settings/presentation/privacy_settings_screen.dart';
import '../features/settings/presentation/island_theme_settings_screen.dart';
import '../features/settings/presentation/blocked_channels_screen.dart';
import '../features/settings/presentation/blocked_videos_screen.dart';
import '../features/settings/presentation/app_log_screen.dart';
import '../features/settings/presentation/debugger_screen.dart';
import '../features/settings/presentation/deploy_guide_screen.dart';
import '../features/settings/presentation/app_deletion_guard_screen.dart';
import '../features/settings/presentation/device_qa_screen.dart';
import '../features/settings/presentation/data_backup_screen.dart';
import '../features/settings/presentation/youtube_filter_settings_screen.dart';
import '../features/settings/presentation/interests_edit_screen.dart';
import '../features/settings/presentation/block_schedule_edit_screen.dart';
import '../features/settings/presentation/block_schedules_screen.dart';
import '../features/settings/presentation/channel_genre_settings_screen.dart';
import '../core/social/instagram_usage_lock.dart';
import '../features/settings/presentation/focus_controls_settings_screens.dart';
import '../features/settings/presentation/brunch_blocked_authors_screen.dart';
import '../features/settings/presentation/feed_boost_settings_screen.dart';
import '../features/settings/presentation/android_system_block_screen.dart';
import '../features/settings/presentation/youtube_default_handler_screen.dart';
import '../features/settings/presentation/app_usage_limits_screen.dart';
import '../features/settings/presentation/browser_youtube_tracking_screen.dart';
import '../features/settings/presentation/youtube_account_sync_screen.dart';
import '../features/settings/presentation/iphone_blocking_capabilities_screen.dart';
import '../features/intervention/presentation/app_limit_intervention_screen.dart';
import '../features/settings/presentation/external_app_control_screen.dart';
import '../features/settings/presentation/safari_youtube_os_block_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/subscription_screen.dart';
import '../features/explorer/presentation/content_explorer_hub_screen.dart';
import '../features/explorer/presentation/web_explorer_screen.dart';
import '../features/social/presentation/social_hub_screen.dart';
import '../features/social/presentation/instagram_hub_screen.dart';
import '../features/social/presentation/my_profile_screen.dart';
import '../features/social/presentation/profile_preview_screen.dart';
import '../features/social/presentation/create_post_screen.dart';
import '../features/social/presentation/isle_social_feed_screen.dart';
import '../core/explorer/explorer_site.dart';
import '../features/youtube/presentation/youtube_browser_screen.dart';
import '../features/youtube/presentation/youtube_guide_screen.dart';
import '../features/insight/presentation/depth_match_screen.dart';
import '../features/insight/presentation/insight_swipe_feed_screen.dart';
import '../features/insight/presentation/living_identity_profile_screen.dart';
import '../core/navigation/center_nav_long_press.dart';
import '../features/youtube/creative_analytics/presentation/creative_analytics_screen.dart';
import '../features/home/presentation/my_isle_hub_screen.dart';
import '../features/home/presentation/my_isle_control_center_screen.dart';
import '../features/youtube/presentation/youtube_hub_screen.dart';
import '../features/youtube/presentation/youtube_login_guide_screen.dart';
import '../features/youtube/presentation/youtube_podcast_screen.dart';
import '../core/youtube/models/youtube_focus_video.dart';
import '../features/youtube_focus/presentation/youtube_focus_home_screen.dart';
import '../features/youtube_focus/presentation/youtube_focus_read_first_screen.dart';
import '../features/youtube_focus/presentation/youtube_focus_results_screen.dart';
import '../features/library/presentation/my_sources_screen.dart';
import '../shared/widgets/isle_bottom_nav.dart';
import 'go_router_refresh.dart';

/// `?tab=growth|outlier|narrative|matchup` 또는 0–3
int creativeAnalyticsTabIndex(String? tab) {
  if (tab == null || tab.isEmpty) return 0;
  switch (tab) {
    case 'growth':
    case 'top3':
    case '0':
      return 0;
    case 'outlier':
    case 'radar':
    case '1':
      return 1;
    case 'narrative':
    case 'anatomy':
    case '2':
      return 2;
    case 'matchup':
    case 'compare':
    case '3':
      return 3;
    default:
      final n = int.tryParse(tab);
      if (n != null && n >= 0 && n <= 3) return n;
      return 0;
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterRefreshStream(ref.watch(authRepoProvider).authStream);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: isleNavigatorKey,
    initialLocation: IsleProductFocus.enabled ? '/home/block' : '/feed',
    refreshListenable: refresh,
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                '이 화면을 열 수 없어요',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                state.error?.toString() ?? state.uri.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/feed'),
                child: const Text('피드로'),
              ),
            ],
          ),
        ),
      ),
    ),
    redirect: (context, state) {
      if (!Env.isSupabaseConfigured) return null;

      final user = Supabase.instance.client.auth.currentUser;
      final loc = state.matchedLocation;

      // 게스트 모드: 로그인 없이 로컬·WebView·소셜 사용 (데이터 유지)
      if (user != null && loc == '/login') {
        return IsleProductFocus.enabled ? '/home/block' : '/feed';
      }
      if (user == null && loc == '/settings/archive') {
        final raw = state.uri.queryParameters['url']?.trim();
        if (raw != null && raw.isNotEmpty && raw.startsWith('http')) {
          unawaited(PendingShareUrlStore.save(raw));
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/login-callback',
        builder: (_, state) => LoginCallbackScreen(uri: state.uri),
      ),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/app-tour', builder: (_, __) => const AppTourScreen()),
      GoRoute(
        path: '/guide/android-visual',
        builder: (_, __) => const AndroidVisualTutorialScreen(),
      ),
      GoRoute(path: '/knowledge/profile', builder: (_, __) => const LivingIdentityProfileScreen()),
      GoRoute(path: '/knowledge/swipe', builder: (_, __) => const InsightSwipeFeedScreen()),
      GoRoute(path: '/knowledge/depth', builder: (_, __) => const DepthMatchScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home/block',
              builder: (_, __) => const BlockHomeScreen(),
              routes: [
                GoRoute(
                  path: 'pomodoro',
                  builder: (_, state) => PomodoroBreakScreen(
                    openRefill: state.uri.queryParameters['tab'] == 'refill',
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home/my-isle',
              builder: (_, __) => const MyIsleHubScreen(),
              routes: [
                GoRoute(
                  path: 'manage',
                  builder: (_, __) => const MyIsleControlCenterScreen(),
                ),
              ],
            ),
            GoRoute(
              path: '/home/youtube',
              redirect: (_, __) => '/home/my-isle',
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/home/share', builder: (_, __) => const ShareHomeScreen()),
            GoRoute(path: '/home/share/playlists', builder: (_, __) => const SharePlaylistScreen()),
            GoRoute(
              path: '/home/share/playlists/:id',
              builder: (_, state) => SharePlaylistDetailScreen(
                playlistId: state.pathParameters['id'] ?? '',
              ),
            ),
            GoRoute(
              path: '/home/share/playlists/import',
              builder: (_, state) => SharePlaylistImportScreen(
                payload: state.uri.queryParameters['data'] ?? '',
              ),
            ),
            GoRoute(
              path: '/home/share/quick-save',
              builder: (_, state) => ShareQuickSaveScreen(
                url: state.uri.queryParameters['url'] ?? '',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/island', builder: (_, __) => const IslandScreen()),
            GoRoute(
              path: '/island/:userId',
              builder: (_, state) => IslandScreen(userId: state.pathParameters['userId']),
            ),
            GoRoute(
              path: '/island/browse',
              builder: (_, state) {
                final i = int.tryParse(state.uri.queryParameters['index'] ?? '') ?? 0;
                return OtherIslandsBrowserScreen(initialIndex: i.clamp(0, 99));
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/social', builder: (_, __) => const SocialHubScreen()),
            GoRoute(path: '/social/instagram', builder: (_, __) => const InstagramHubScreen()),
            GoRoute(path: '/social/profile', builder: (_, __) => const MyProfileScreen()),
            GoRoute(path: '/social/profile/preview', builder: (_, __) => const ProfilePreviewScreen()),
            GoRoute(path: '/social/post/new', builder: (_, __) => const CreatePostScreen()),
            GoRoute(path: '/social/feed', builder: (_, __) => const IsleSocialFeedScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/focus', builder: (_, __) => const FocusHubScreen()),
            GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen()),
            GoRoute(path: '/explore/requests', builder: (_, __) => const RequestInboxScreen()),
            GoRoute(
              path: '/explore/chat/:peerUserId',
              builder: (_, state) => ChatGateScreen(
                peerUserId: state.pathParameters['peerUserId'] ?? '',
                peerName: state.uri.queryParameters['name'] ?? 'User',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
            GoRoute(path: '/settings/subscriptions', builder: (_, __) => const SubscriptionScreen()),
            GoRoute(path: '/settings/interests', builder: (_, __) => const InterestsEditScreen()),
            GoRoute(path: '/settings/feed-boost', builder: (_, __) => const FeedBoostSettingsScreen()),
            GoRoute(
              path: '/settings/brunch-blocked',
              builder: (_, __) => const BrunchBlockedAuthorsScreen(),
            ),
            GoRoute(path: '/settings/blocked', builder: (_, __) => const BlockedChannelsScreen()),
            GoRoute(path: '/settings/blocked-videos', builder: (_, __) => const BlockedVideosScreen()),
            GoRoute(
              path: '/settings/youtube-filter',
              builder: (_, __) => const YoutubeFilterSettingsScreen(),
            ),
            GoRoute(
              path: '/settings/channel-genre',
              builder: (_, __) => const ChannelGenreSettingsScreen(),
            ),
            GoRoute(
              path: '/settings/youtube-limits',
              builder: (_, __) => const YoutubeLimitsSettingsScreen(),
            ),
            GoRoute(
              path: '/settings/instagram-limits',
              builder: (_, state) {
                final scope = state.uri.queryParameters['scope'];
                InstagramUsageScope? initial;
                if (scope == 'dm') {
                  initial = InstagramUsageScope.dm;
                } else if (scope == 'feed') {
                  initial = InstagramUsageScope.feed;
                }
                return InstagramLimitsSettingsScreen(initialScope: initial);
              },
            ),
            GoRoute(
              path: '/settings/external-apps',
              builder: (_, __) => const ExternalAppControlScreen(),
            ),
            GoRoute(
              path: '/settings/browser-youtube-tracking',
              builder: (_, __) => const BrowserYoutubeTrackingScreen(),
            ),
            GoRoute(
              path: '/settings/youtube-account-sync',
              builder: (_, __) => const YoutubeAccountSyncScreen(),
            ),
            GoRoute(
              path: '/settings/app-usage-limits',
              builder: (_, state) => AppUsageLimitsScreen(
                scheduleId: state.uri.queryParameters['scheduleId'],
              ),
            ),
            GoRoute(
              path: '/intervention/limit',
              builder: (_, state) => AppLimitInterventionScreen(
                title: state.uri.queryParameters['title'] ?? '오늘 한도에 도달했어요',
                body: state.uri.queryParameters['body'] ??
                    '잠시 쉬었다가 Isle에서 의도한 콘텐츠만 보세요.',
                usedMinutes: int.tryParse(state.uri.queryParameters['used'] ?? ''),
                limitMinutes: int.tryParse(state.uri.queryParameters['limit'] ?? ''),
              ),
            ),
            GoRoute(
              path: '/settings/safari-youtube-os',
              builder: (_, __) => const SafariYoutubeOsBlockScreen(),
            ),
            GoRoute(
              path: '/settings/android-system-block',
              builder: (_, __) => const AndroidSystemBlockScreen(),
            ),
            GoRoute(
              path: '/settings/youtube-default-open',
              builder: (_, __) => const YoutubeDefaultHandlerScreen(),
            ),
            GoRoute(
              path: '/settings/iphone-blocking',
              builder: (_, __) => const IphoneBlockingCapabilitiesScreen(),
            ),
            GoRoute(
              path: '/settings/block-schedules',
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
              path: '/settings/api-budget',
              redirect: (_, __) => '/settings/ai-hub',
            ),
            GoRoute(path: '/settings/ai-hub', builder: (_, __) => const AiHubScreen()),
            GoRoute(path: '/settings/block-chat', builder: (_, __) => const BlockChatScreen()),
            GoRoute(path: '/settings/ai-usage-log', builder: (_, __) => const AiUsageLogScreen()),
            GoRoute(
              path: '/settings/interest-pipeline',
              builder: (_, __) => const InterestPipelineSettingsScreen(),
            ),
            GoRoute(path: '/settings/privacy', builder: (_, __) => const PrivacySettingsScreen()),
            GoRoute(path: '/settings/island-theme', builder: (_, __) => const IslandThemeSettingsScreen()),
            GoRoute(path: '/settings/platform-stats', builder: (_, __) => const PlatformUsageStatsScreen()),
            GoRoute(path: '/settings/backup', builder: (_, __) => const DataBackupScreen()),
            GoRoute(path: '/settings/app-log', builder: (_, __) => const AppLogScreen()),
            GoRoute(path: '/settings/debugger', builder: (_, __) => const DebuggerScreen()),
            GoRoute(path: '/settings/device-qa', builder: (_, __) => const DeviceQaScreen()),
            GoRoute(path: '/settings/deploy-guide', builder: (_, __) => const DeployGuideScreen()),
            GoRoute(
              path: '/settings/app-deletion-guard',
              builder: (_, __) => const AppDeletionGuardScreen(),
            ),
            GoRoute(
              path: '/settings/archive',
              builder: (_, state) => ArchiveInputScreen(initialUrl: state.uri.queryParameters['url']),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/viewer',
        builder: (_, state) => ContentViewerScreen(
          url: state.uri.queryParameters['url'] ?? '',
          title: state.uri.queryParameters['title'] ?? '',
        ),
      ),
      GoRoute(path: '/explore', builder: (_, __) => const ContentExplorerHubScreen()),
      GoRoute(
        path: '/explore/browser',
        builder: (_, state) {
          final site = ExplorerSite.fromQuery(state.uri.queryParameters['site']);
          final url = state.uri.queryParameters['url'];
          return WebExplorerScreen(
            site: site,
            initialUrl: url,
            autoLogin: state.uri.queryParameters['autologin'] == '1',
            brunchPromptLogin: state.uri.queryParameters['remember_login'] == '1',
            instagramDmOnly: state.uri.queryParameters['dm'] == '1',
          );
        },
      ),
      GoRoute(path: '/youtube', builder: (_, __) => const YoutubeHubScreen()),
      GoRoute(
        path: '/youtube/browser',
        builder: (_, state) => YoutubeBrowserScreen(
          autoLogin: state.uri.queryParameters['autologin'] == '1',
          initialUrl: state.uri.queryParameters['url'],
          loginOnly: state.uri.queryParameters['login_only'] == '1',
        ),
      ),
      GoRoute(
        path: '/youtube/podcast',
        builder: (_, state) => YoutubePodcastScreen(
          initialUrl: state.uri.queryParameters['url'],
          videoId: state.uri.queryParameters['v'],
        ),
      ),
      GoRoute(
        path: '/youtube/limits',
        builder: (_, __) => const YoutubeLimitsSettingsScreen(),
      ),
      GoRoute(
        path: '/youtube/creative-analytics',
        builder: (_, state) => CreativeAnalyticsScreen(
          initialTabIndex: creativeAnalyticsTabIndex(state.uri.queryParameters['tab']),
        ),
      ),
      GoRoute(path: '/youtube/guide', builder: (_, __) => const YoutubeGuideScreen()),
      GoRoute(path: '/youtube/login-guide', builder: (_, __) => const YoutubeLoginGuideScreen()),
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
            video: YoutubeFocusVideo(
              videoId: id,
              title: 'YouTube',
              channelName: '',
            ),
          );
        },
      ),
      GoRoute(path: '/library/sources', builder: (_, __) => const MySourcesScreen()),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

class MainShell extends StatefulWidget {
  final StatefulNavigationShell shell;
  const MainShell({super.key, required this.shell});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// 3탭 홈: 0 차단 · 1 유튜브 · 2 공유
  int _focusNavIndex = 0;

  static const _classicBranchOffset = 3;

  @override
  void initState() {
    super.initState();
    _syncFocusNavFromShell();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Platform.isAndroid) {
        unawaited(maybeShowAndroidVisualTutorial(context));
      }
    });
  }

  void _syncFocusNavFromShell() {
    if (!IsleProductFocus.enabled) return;
    final b = widget.shell.currentIndex;
    if (b <= 2) _focusNavIndex = b;
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocusNavFromShell();
  }

  void _onFocusNav(int i) {
    setState(() => _focusNavIndex = i);
    widget.shell.goBranch(i, initialLocation: widget.shell.currentIndex == i);
  }

  void _onClassicNav(int i) {
    widget.shell.goBranch(
      i + _classicBranchOffset,
      initialLocation: widget.shell.currentIndex == i + _classicBranchOffset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final focus = IsleProductFocus.enabled;
    final navIndex = focus
        ? _focusNavIndex
        : (widget.shell.currentIndex - _classicBranchOffset).clamp(0, 4);

    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: IsleBottomNav(
        currentIndex: navIndex,
        onTap: focus ? _onFocusNav : _onClassicNav,
        onCenterLongPress: focus ? () => handleCenterNavLongPress(context) : null,
      ),
    );
  }
}
