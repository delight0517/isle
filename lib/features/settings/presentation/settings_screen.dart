import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_build_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_release_info.dart';
import '../../../core/constants/env.dart';
import '../../../core/services/isle_app_update_provider.dart';
import '../../../core/focus/isle_product_focus.dart';
import '../../../core/navigation/center_nav_long_press.dart';
import '../../../core/navigation/isle_routes.dart';
import '../../../core/platform/platform_block_intent.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/settings_strings.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../ai/presentation/block_audit_log_pasteboard.dart';
import '../../auth/providers/auth_provider.dart';
import '../../feed/presentation/widgets/block_from_link_sheet.dart';
import '../../feed/presentation/widgets/keyword_filter_sheet.dart';
import '../../island/presentation/widgets/island_cloud_transition.dart';
import '../../../shared/widgets/isle_sheet.dart';
import 'isle_backup_code_sheet.dart';
import '../../auth/presentation/blue_cloud_account_sheet.dart';
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
    final currentCode = ref.watch(appLocaleProvider)?.languageCode ??
        Localizations.localeOf(context).languageCode;
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
            _profileHeader(profile?.displayName ?? s.t('user'),
                profile?.username ?? 'isle_user'),
            _auditLogCopyCard(context),
            if (focus) ...[
              _youtubeHeroCard(context, st),
              _section(st.t('section_focus')),
              _tile(Icons.timer_outlined, st.t('app_usage_limits'),
                  () => context.push('/settings/app-usage-limits'),
                  subtitle: st.t('app_usage_limits_sub')),
              _tile(Icons.shield_outlined, st.t('external_apps'),
                  () => context.push('/settings/external-apps'),
                  subtitle: st.t(PlatformBlockCopy.isAndroid
                      ? 'external_apps_android_sub'
                      : 'external_apps_apple_sub')),
              _tile(Icons.track_changes, st.t('browser_tracking'),
                  () => context.push(PlatformBlockCopy.settingsRoute),
                  subtitle: st.t(PlatformBlockCopy.isAndroid
                      ? 'browser_tracking_android_sub'
                      : PlatformBlockCopy.isMac
                          ? 'browser_tracking_mac_sub'
                          : 'browser_tracking_ios_sub')),
              _tile(Icons.play_circle_outline, st.t('youtube_webview'),
                  () => context.push('/youtube/browser'),
                  subtitle: st.t('youtube_webview_sub')),
              _section(st.t('section_youtube_watch')),
              _tile(
                Icons.account_circle_outlined,
                st.t('youtube_account'),
                () => context.push('/settings/youtube-account-sync'),
                subtitle: st.t('youtube_account_sub'),
              ),
              _tile(Icons.timer_outlined, st.t('daily_watch_limit'),
                  () => context.push(IsleRoutes.youtubeLimits)),
              _tile(Icons.camera_alt_outlined, st.t('instagram_limits'),
                  () => context.push('/settings/instagram-limits'),
                  subtitle: st.t('instagram_limits_sub')),
              _tile(Icons.schedule, st.t('app_schedules'),
                  () => context.push('/settings/block-schedules')),
              _tile(
                  Icons.phone_iphone,
                  st.t(PlatformBlockCopy.isAndroid
                      ? 'capabilities_android'
                      : 'capabilities_apple'),
                  () => context.push('/settings/iphone-blocking')),
              _tile(Icons.block, st.t('blocked_channels'),
                  () => context.push('/settings/blocked')),
              _tile(Icons.category_outlined, st.t('genre_block'),
                  () => context.push('/settings/channel-genre')),
              _tile(Icons.badge_outlined, st.t('knowledge_profile'),
                  () => context.push('/knowledge/profile')),
              _tile(Icons.link, st.t('save_links'),
                  () => context.go('/home/share')),
              _tile(Icons.touch_app_outlined, st.t('nav_long_press'),
                  () => showCenterNavPickerSheet(context),
                  subtitle: st.t('nav_long_press_sub')),
              _tile(Icons.open_in_new, st.t('youtube_open_isle'),
                  () => context.push('/settings/youtube-default-open')),
              _tile(Icons.public, st.t('default_browser'),
                  () => context.push('/settings/default-browser'),
                  subtitle: st.t(PlatformBlockCopy.isAndroid
                      ? 'default_browser_android_sub'
                      : 'default_browser_apple_sub')),
              _tile(Icons.shield_outlined, st.t('safe_browser'),
                  () => context.push('/home/share/safe-browser'),
                  subtitle: st.t('safe_browser_sub')),
              _tile(Icons.tune, st.t('youtube_filter'),
                  () => context.push('/settings/youtube-filter')),
              _tile(Icons.bar_chart_outlined, st.t('platform_stats'),
                  () => context.push('/settings/platform-stats')),
              _section(st.t('section_app')),
              _tile(Icons.system_update_alt, st.t('check_updates'),
                  () => runIsleAppUpdateCheck(context, ref, manual: true),
                  subtitle: st.t('update_version',
                      args: {'version': AppReleaseInfo.label})),
              _tile(Icons.language, s.t('language'),
                  () => _openLanguageSheet(context, ref, s),
                  subtitle:
                      AppStrings.languageOptions[currentCode] ?? currentCode),
              _tile(Icons.cloud_outlined, st.t('bluecloud_account'),
                  () => showBlueCloudAccountSheet(context),
                  subtitle: st.t('bluecloud_account_sub')),
              _backupCard(context, ref, st, compact: true),
              _advancedToggle(st),
              if (_showAdvanced)
                ..._advancedTiles(context, ref, s, st, currentCode),
            ] else
              ..._classicTiles(context, ref, s, st, currentCode),
            const Divider(indent: 16),
            _tile(Icons.policy_outlined, st.t('privacy_policy'),
                () => context.push('/settings/privacy-policy')),
            _tile(Icons.delete_forever_outlined, st.t('account_data_delete'),
                () => context.push('/settings/account-deletion'),
                subtitle: st.t('account_data_delete_sub')),
            _tile(Icons.logout, s.t('logout'), () async {
              await ref.read(authRepoProvider).signOut();
              if (context.mounted) context.go('/login');
            }, color: IsleColors.danger),
          ],
        ),
      ),
    );
  }

  /// "지난 2주간 log 전부 복사하기" — 설정 맨 위(프로필 바로 아래) 원탭 버튼
  /// (2026-07-16 사용자 요청). 채팅으로 스케줄이 통째로 리셋됐을 때 "언제·
  /// 어디서·어떤 커맨드가 그랬는지" 바로 복사해서 AI에 붙여넣을 수 있게.
  Widget _auditLogCopyCard(BuildContext context) {
    final st = SettingsStrings.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        color: IsleColors.ocean100.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.history,
                      size: 18, color: IsleColors.ocean700),
                  const SizedBox(width: 6),
                  Text(st.t('audit_title'), style: IsleText.subtitle()),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                st.t('audit_sub'),
                style: IsleText.caption(color: IsleColors.muted),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => BlockAuditLogPasteboard.copyAll(context),
                icon: const Icon(Icons.copy_all),
                label: Text(st.t('audit_copy')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push('/block/audit-log'),
                icon: const Icon(Icons.list_alt),
                label: Text(st.t('audit_detail')),
              ),
            ],
          ),
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
                st.t('youtube_hero_sub',
                    args: {'browser': PlatformBlockCopy.externalBrowserName}),
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
      _tile(Icons.library_books, st.t('my_library'),
          () => context.push('/library/sources')),
      _tile(Icons.rss_feed, s.t('subscription_management'),
          () => context.push('/settings/subscriptions')),
      _tile(Icons.interests, s.t('edit_interests'),
          () => context.push('/settings/interests')),
      _section(st.t('section_sns')),
      if (AppBuildConfig.enableSocialUgc)
        _tile(Icons.hub_outlined, st.t('social_hub'),
            () => context.push('/social')),
      _tile(Icons.landscape_outlined, st.t('browse_islands'), () async {
        await runIslandCloudTransition(context, () async {
          if (context.mounted) await context.push('/island/browse');
        });
      }),
      _tile(Icons.cabin_outlined, s.t('island_theme'),
          () => context.push('/settings/island-theme')),
      _section(st.t('section_ai')),
      _tile(Icons.explore_outlined, st.t('explore_hub'),
          () => context.push('/explore')),
      _tile(Icons.auto_awesome, st.t('ai_hub'),
          () => context.push('/settings/ai-hub')),
      _tile(Icons.spa_outlined, st.t('focus_mode'),
          () => context.push('/youtube-focus')),
      _tile(Icons.category_outlined, st.t('genre_block'),
          () => context.push('/settings/channel-genre')),
      _tile(Icons.person_off_outlined, st.t('brunch_hidden'),
          () => context.push('/settings/brunch-blocked')),
      _section(st.t('section_feed_filter')),
      _tile(Icons.link, st.t('hide_by_link'),
          () => showBlockFromLinkSheet(context)),
      _tile(Icons.tag, st.t('hide_keywords'),
          () => showKeywordFilterSheet(context)),
      _section(st.t('section_app')),
      _tile(
        Icons.menu_book_outlined,
        Platform.isAndroid ? st.t('visual_guide') : st.t('app_tour'),
        () => context
            .push(Platform.isAndroid ? '/guide/android-visual' : '/app-tour'),
        subtitle: Platform.isAndroid ? st.t('visual_guide_sub') : null,
      ),
      _tile(Icons.language, s.t('language'),
          () => _openLanguageSheet(context, ref, s),
          subtitle: AppStrings.languageOptions[currentCode] ?? currentCode),
      _tile(Icons.system_update_alt, st.t('check_updates'),
          () => runIsleAppUpdateCheck(context, ref, manual: true),
          subtitle:
              st.t('update_version', args: {'version': AppReleaseInfo.label})),
      _tile(Icons.checklist_rtl, st.t('device_qa'),
          () => context.push('/settings/device-qa'),
          subtitle: st.t('device_qa_sub')),
      _tile(Icons.cloud_outlined, st.t('bluecloud_account'),
          () => showBlueCloudAccountSheet(context),
          subtitle: st.t('bluecloud_account_sub')),
      _tile(Icons.bug_report_outlined, st.t('debug'),
          () => context.push('/settings/debugger')),
      SwitchListTile(
        title: Text(st.t('full_ui')),
        subtitle: Text(st.t('full_ui_sub')),
        value: !IsleProductFocus.enabled,
        onChanged: (v) async {
          await IsleUserDefaults.setProductFocusUi(!v);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(v ? st.t('full_ui_on') : st.t('full_ui_off'))),
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
      _tile(Icons.library_books, st.t('my_library'),
          () => context.push('/library/sources')),
      _tile(
        Icons.account_circle_outlined,
        st.t('youtube_account'),
        () => context.push('/settings/youtube-account-sync'),
        subtitle: st.t('youtube_account_sub'),
      ),
      _tile(Icons.interests, s.t('edit_interests'),
          () => context.push('/settings/interests')),
      _tile(Icons.rss_feed, s.t('subscription_management'),
          () => context.push('/settings/subscriptions')),
      _tile(Icons.landscape_outlined, st.t('browse_islands'),
          () => context.push('/island/browse')),
      _section(st.t('section_time_block')),
      _tile(Icons.track_changes, st.t('browser_tracking'),
          () => context.push(PlatformBlockCopy.settingsRoute)),
      _tile(Icons.shield_outlined, st.t('other_apps_block'),
          () => context.push('/settings/external-apps')),
      _section(st.t('section_youtube')),
      _tile(Icons.explore_outlined, st.t('explore_short'),
          () => context.push('/explore')),
      _tile(Icons.ondemand_video, st.t('youtube_short'),
          () => context.push('/youtube/browser')),
      _tile(Icons.timer_outlined, st.t('watch_limit_short'),
          () => context.push(IsleRoutes.youtubeLimits)),
      _tile(Icons.schedule, st.t('app_schedules'),
          () => context.push('/settings/block-schedules')),
      if (AppBuildConfig.enableSocialUgc)
        _tile(Icons.hub_outlined, st.t('social_short'),
            () => context.push('/social')),
      _tile(Icons.auto_awesome, st.t('ai_hub'),
          () => context.push('/settings/ai-hub')),
      _tile(Icons.lock_outline, s.t('privacy_settings'),
          () => context.push('/settings/privacy')),
      _tile(Icons.save_alt, st.t('backup_detail'),
          () => context.push('/settings/backup')),
      _tile(Icons.cloud_outlined, st.t('bluecloud_account'),
          () => showBlueCloudAccountSheet(context),
          subtitle: st.t('bluecloud_account_sub')),
      _tile(Icons.language, s.t('language'),
          () => _openLanguageSheet(context, ref, s),
          subtitle: AppStrings.languageOptions[currentCode] ?? currentCode),
      _tile(Icons.system_update_alt, st.t('check_updates'),
          () => runIsleAppUpdateCheck(context, ref, manual: true),
          subtitle:
              st.t('update_version', args: {'version': AppReleaseInfo.label})),
      if (Env.isSupabaseConfigured)
        _tile(Icons.link, s.t('archive_by_url'),
            () => context.push('/settings/archive')),
      SwitchListTile(
        title: Text(st.t('focus_ui')),
        subtitle: Text(st.t('focus_ui_sub')),
        value: IsleProductFocus.enabled,
        onChanged: (v) async {
          await IsleUserDefaults.setProductFocusUi(v);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text(v ? st.t('focus_ui_on') : st.t('full_ui_snack'))),
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
              Text('@$username',
                  style: IsleText.caption(color: IsleColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _backupCard(BuildContext context, WidgetRef ref, SettingsStrings st,
      {required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 0 : 0, 16, 8),
      child: Card(
        color: IsleColors.ocean100,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(st.t('data_backup'),
                  style: IsleText.subtitle(color: IsleColors.ocean900)),
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
        child: Text(title,
            style: IsleText.caption(color: IsleColors.muted)
                .copyWith(fontWeight: FontWeight.w600)),
      );

  Widget _tile(IconData icon, String title, VoidCallback onTap,
          {Color? color, String? subtitle}) =>
      ListTile(
        leading: Icon(icon, color: color ?? IsleColors.ocean700, size: 22),
        title: Text(title, style: IsleText.body(color: color)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
        trailing: color == null
            ? const Icon(Icons.chevron_right, color: IsleColors.muted)
            : null,
        onTap: onTap,
      );
}

void _openLanguageSheet(BuildContext context, WidgetRef ref, AppStrings s) {
  final st = SettingsStrings.of(context);
  final currentCode = ref.read(appLocaleProvider)?.languageCode ??
      Localizations.localeOf(context).languageCode;
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
            child:
                Text(st.t('language_sheet_title'), style: IsleText.subtitle()),
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
                  trailing: selected
                      ? const Icon(Icons.check, color: IsleColors.ocean500)
                      : null,
                  onTap: () {
                    ref.read(appLocaleProvider.notifier).setLocaleCode(e.key);
                    Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                SettingsStrings(e.key).t('language_changed'))),
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
              style: IsleText.caption(color: IsleColors.muted)
                  .copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );
}
