import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/env.dart';
import '../../../core/focus/isle_product_focus.dart';
import '../../../core/navigation/center_nav_long_press.dart';
import '../../../core/navigation/isle_routes.dart';
import '../../../core/platform/platform_block_intent.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/settings_strings.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../auth/providers/auth_provider.dart';
import '../../feed/presentation/widgets/block_from_link_sheet.dart';
import '../../feed/presentation/widgets/keyword_filter_sheet.dart';
import '../../island/presentation/widgets/island_cloud_transition.dart';
import '../../../shared/widgets/isle_sheet.dart';
import 'isle_backup_code_sheet.dart';
import 'widgets/ai_setup_promo_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _showAdvanced = IsleProductFocus.showAdvanced;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProvider);
    final s = AppStrings.of(context);
    final st = SettingsStrings.of(context);
    final currentCode =
        ref.watch(appLocaleProvider)?.languageCode ?? Localizations.localeOf(context).languageCode;
    final focus = IsleProductFocus.enabled;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(s.t('settings'), style: IsleText.subtitle()),
        centerTitle: false,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(s.t('profile_load_failed'))),
        data: (profile) => ListView(
          children: [
            _profileHeader(profile?.displayName ?? s.t('user'), profile?.username ?? 'isle_user'),
            if (focus) ...[
              _youtubeHeroCard(context, st),
              _section(st.t('section_focus')),
              _tile(Icons.timer_outlined, st.t('app_usage_limits'), () => context.push('/settings/app-usage-limits'),
                  subtitle: st.t('app_usage_limits_sub')),
              _tile(Icons.shield_outlined, st.t('external_apps'), () => context.push('/settings/external-apps'),
                  subtitle: st.t('external_apps_sub')),
              _tile(Icons.track_changes, PlatformBlockCopy.settingsTileTitle,
                  () => context.push(PlatformBlockCopy.settingsRoute),
                  subtitle: PlatformBlockCopy.settingsTileSubtitle),
              _tile(Icons.play_circle_outline, st.t('youtube_webview'), () => context.push('/youtube/browser'),
                  subtitle: st.t('youtube_webview_sub')),
              _section(st.t('section_youtube_watch')),
              _tile(
                Icons.account_circle_outlined,
                'YouTube 계정 · 나중에 볼 동기화',
                () => context.push('/settings/youtube-account-sync'),
                subtitle: 'Google 로그인 · 플레이리스트 자동 저장',
              ),
              _tile(Icons.timer_outlined, st.t('daily_watch_limit'), () => context.push(IsleRoutes.youtubeLimits)),
              _tile(Icons.camera_alt_outlined, 'Instagram 피드·DM 한도',
                  () => context.push('/settings/instagram-limits'),
                  subtitle: '각각 일일 한도 · 이용 중 타임락'),
              _tile(Icons.schedule, st.t('app_schedules'), () => context.push('/settings/block-schedules')),
              _tile(Icons.phone_iphone, st.t('iphone_blocking_guide'),
                  () => context.push('/settings/iphone-blocking')),
              _tile(Icons.block, st.t('blocked_channels'), () => context.push('/settings/blocked')),
              _tile(Icons.category_outlined, st.t('genre_block'), () => context.push('/settings/channel-genre')),
              _tile(Icons.badge_outlined, '지식 명함', () => context.push('/knowledge/profile')),
              _tile(Icons.link, '링크·자막 저장', () => context.go('/home/share')),
              _tile(Icons.touch_app_outlined, '하단 버튼 길게 누르기', () => showCenterNavPickerSheet(context),
                  subtitle: 'YouTube / Instagram 기본 열기'),
              _tile(Icons.open_in_new, st.t('youtube_open_isle'), () => context.push('/settings/youtube-default-open')),
              _tile(Icons.tune, st.t('youtube_filter'), () => context.push('/settings/youtube-filter')),
              _tile(Icons.bar_chart_outlined, st.t('platform_stats'), () => context.push('/settings/platform-stats')),
              _section(st.t('section_app')),
              _tile(Icons.language, s.t('language'), () => _openLanguageSheet(context, ref, s),
                  subtitle: AppStrings.languageOptions[currentCode] ?? currentCode),
              _backupCard(context, ref, st, compact: true),
              _advancedToggle(st),
              if (_showAdvanced) ..._advancedTiles(context, ref, s, st, currentCode),
            ] else
              ..._classicTiles(context, ref, s, st, currentCode),
            const Divider(indent: 16),
            _tile(Icons.logout, s.t('logout'), () async {
              await ref.read(authRepoProvider).signOut();
              if (context.mounted) context.go('/login');
            }, color: IsleColors.danger),
          ],
        ),
      ),
    );
  }

  Widget _youtubeHeroCard(BuildContext context, SettingsStrings st) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        color: const Color(0xFFFF0000).withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(st.t('youtube_hero_title'), style: IsleText.subtitle()),
              const SizedBox(height: 4),
              Text(
                st.t('youtube_hero_sub', args: {'browser': PlatformBlockCopy.externalBrowserName}),
                style: IsleText.caption(color: IsleColors.muted),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => context.push(PlatformBlockCopy.settingsRoute),
                icon: const Icon(Icons.track_changes),
                label: Text(st.t('browser_block_setup')),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push('/youtube/browser'),
                icon: const Icon(Icons.play_circle_outline),
                label: Text(st.t('open_youtube_webview')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _advancedToggle(SettingsStrings st) {
    return SwitchListTile(
      title: Text(st.t('advanced_ui'), style: IsleText.body()),
      subtitle: Text(
        st.t('advanced_ui_sub'),
        style: IsleText.caption(color: IsleColors.muted),
      ),
      value: _showAdvanced,
      onChanged: (v) async {
        await IsleUserDefaults.setShowAdvancedUi(v);
        setState(() => _showAdvanced = v);
      },
    );
  }

  List<Widget> _advancedTiles(
    BuildContext context,
    WidgetRef ref,
    AppStrings s,
    SettingsStrings st,
    String currentCode,
  ) {
    return [
      _section(st.t('section_content')),
      _tile(Icons.library_books, st.t('my_library'), () => context.push('/library/sources')),
      _tile(Icons.rss_feed, s.t('subscription_management'), () => context.push('/settings/subscriptions')),
      _tile(Icons.interests, s.t('edit_interests'), () => context.push('/settings/interests')),
      _section(st.t('section_sns')),
      _tile(Icons.hub_outlined, st.t('social_hub'), () => context.push('/social')),
      _tile(Icons.landscape_outlined, st.t('browse_islands'), () async {
        await runIslandCloudTransition(context, () async {
          if (context.mounted) await context.push('/island/browse');
        });
      }),
      _tile(Icons.cabin_outlined, s.t('island_theme'), () => context.push('/settings/island-theme')),
      _section(st.t('section_ai')),
      _tile(Icons.explore_outlined, st.t('explore_hub'), () => context.push('/explore')),
      _tile(Icons.auto_awesome, st.t('ai_hub'), () => context.push('/settings/ai-hub')),
      _tile(Icons.spa_outlined, st.t('focus_mode'), () => context.push('/youtube-focus')),
      _tile(Icons.category_outlined, st.t('genre_block'), () => context.push('/settings/channel-genre')),
      _tile(Icons.thumb_up_alt_outlined, st.t('feed_boost'), () => context.push('/settings/feed-boost')),
      _tile(Icons.person_off_outlined, st.t('brunch_hidden'), () => context.push('/settings/brunch-blocked')),
      _section(st.t('section_feed_filter')),
      _tile(Icons.link, st.t('hide_by_link'), () => showBlockFromLinkSheet(context)),
      _tile(Icons.tag, st.t('hide_keywords'), () => showKeywordFilterSheet(context)),
      _section(st.t('section_app')),
      _tile(
        Icons.menu_book_outlined,
        Platform.isAndroid ? 'Isle 쉬운 설명 (그림)' : st.t('app_tour'),
        () => context.push(Platform.isAndroid ? '/guide/android-visual' : '/app-tour'),
        subtitle: Platform.isAndroid ? '처음 한 번만 자동 · 여기서 다시 보기' : null,
      ),
      _tile(Icons.language, s.t('language'), () => _openLanguageSheet(context, ref, s),
          subtitle: AppStrings.languageOptions[currentCode] ?? currentCode),
      _tile(Icons.checklist_rtl, '실기기 확인 (TODO)', () => context.push('/settings/device-qa'),
          subtitle: '§1 체크리스트 · 화면 바로가기'),
      _tile(Icons.bug_report_outlined, st.t('debug'), () => context.push('/settings/debugger')),
      SwitchListTile(
        title: Text(st.t('full_ui')),
        subtitle: Text(st.t('full_ui_sub')),
        value: !IsleProductFocus.enabled,
        onChanged: (v) async {
          await IsleUserDefaults.setProductFocusUi(!v);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(v ? st.t('full_ui_on') : st.t('full_ui_off'))),
            );
          }
        },
      ),
    ];
  }

  List<Widget> _classicTiles(
    BuildContext context,
    WidgetRef ref,
    AppStrings s,
    SettingsStrings st,
    String currentCode,
  ) {
    return [
      _backupCard(context, ref, st, compact: false),
      const AiSetupPromoCard(),
      _section(st.t('section_content_short')),
      _tile(Icons.library_books, st.t('my_library'), () => context.push('/library/sources')),
      _tile(
        Icons.account_circle_outlined,
        'YouTube 계정 · 나중에 볼 동기화',
        () => context.push('/settings/youtube-account-sync'),
        subtitle: 'Google 로그인 · 자동 저장',
      ),
      _tile(Icons.interests, s.t('edit_interests'), () => context.push('/settings/interests')),
      _tile(Icons.rss_feed, s.t('subscription_management'), () => context.push('/settings/subscriptions')),
      _tile(Icons.landscape_outlined, st.t('browse_islands'), () => context.push('/island/browse')),
      _section(st.t('section_time_block')),
      _tile(Icons.track_changes, PlatformBlockCopy.settingsTileTitle,
          () => context.push(PlatformBlockCopy.settingsRoute)),
      _tile(Icons.shield_outlined, st.t('other_apps_block'), () => context.push('/settings/external-apps')),
      _section(st.t('section_youtube')),
      _tile(Icons.explore_outlined, st.t('explore_short'), () => context.push('/explore')),
      _tile(Icons.ondemand_video, st.t('youtube_short'), () => context.push('/youtube/browser')),
      _tile(Icons.timer_outlined, st.t('watch_limit_short'), () => context.push(IsleRoutes.youtubeLimits)),
      _tile(Icons.schedule, st.t('app_schedules'), () => context.push('/settings/block-schedules')),
      _tile(Icons.hub_outlined, st.t('social_short'), () => context.push('/social')),
      _tile(Icons.auto_awesome, st.t('ai_hub'), () => context.push('/settings/ai-hub')),
      _tile(Icons.lock_outline, s.t('privacy_settings'), () => context.push('/settings/privacy')),
      _tile(Icons.save_alt, st.t('backup_detail'), () => context.push('/settings/backup')),
      _tile(Icons.language, s.t('language'), () => _openLanguageSheet(context, ref, s),
          subtitle: AppStrings.languageOptions[currentCode] ?? currentCode),
      if (Env.isSupabaseConfigured)
        _tile(Icons.link, s.t('archive_by_url'), () => context.push('/settings/archive')),
      SwitchListTile(
        title: Text(st.t('focus_ui')),
        subtitle: Text(st.t('focus_ui_sub')),
        value: IsleProductFocus.enabled,
        onChanged: (v) async {
          await IsleUserDefaults.setProductFocusUi(v);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(v ? st.t('focus_ui_on') : st.t('full_ui_snack'))),
            );
          }
        },
      ),
    ];
  }

  Widget _profileHeader(String name, String username) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: IsleColors.ocean100,
            child: Icon(Icons.person, color: IsleColors.ocean500, size: 28),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: IsleText.subtitle()),
              Text('@$username', style: IsleText.caption(color: IsleColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _backupCard(BuildContext context, WidgetRef ref, SettingsStrings st, {required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 0 : 0, 16, 8),
      child: Card(
        color: IsleColors.ocean100,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(st.t('data_backup'), style: IsleText.subtitle(color: IsleColors.ocean900)),
              if (!compact) ...[
                const SizedBox(height: 6),
                Text(
                  st.t('data_backup_sub'),
                  style: IsleText.caption(color: IsleColors.ocean700),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => showIsleBackupCodeSheet(context, ref),
                icon: const Icon(Icons.qr_code_2),
                label: Text(st.t('backup_code')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        child: Text(title, style: IsleText.caption(color: IsleColors.muted).copyWith(fontWeight: FontWeight.w600)),
      );

  Widget _tile(IconData icon, String title, VoidCallback onTap, {Color? color, String? subtitle}) =>
      ListTile(
        leading: Icon(icon, color: color ?? IsleColors.ocean700, size: 22),
        title: Text(title, style: IsleText.body(color: color)),
        subtitle: subtitle == null ? null : Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
        trailing: color == null ? const Icon(Icons.chevron_right, color: IsleColors.muted) : null,
        onTap: onTap,
      );
}

void _openLanguageSheet(BuildContext context, WidgetRef ref, AppStrings s) {
  final st = SettingsStrings.of(context);
  final currentCode = ref.read(appLocaleProvider)?.languageCode ?? Localizations.localeOf(context).languageCode;
  showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(st.t('language_sheet_title'), style: IsleText.subtitle()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              s.t('language_desc'),
              style: IsleText.caption(color: IsleColors.muted),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: AppStrings.languageOptions.entries.map((e) {
                final selected = e.key == currentCode;
                return ListTile(
                  title: Text(e.value),
                  trailing: selected ? const Icon(Icons.check, color: IsleColors.ocean500) : null,
                  onTap: () {
                    ref.read(appLocaleProvider.notifier).setLocaleCode(e.key);
                    Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(st.t('language_changed'))),
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              s.t('language_scope_note'),
              style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );
}
