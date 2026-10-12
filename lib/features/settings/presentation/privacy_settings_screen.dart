import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_legal_info.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/env.dart';
import '../../../core/library/personal_library_store.dart';
import '../../../core/library/youtube_watch_history_service.dart';
import '../../../core/platform/isle_web_session_persistence_service.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../auth/data/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../../core/safety/adult_protection_service.dart';
import '../../home/presentation/widgets/adult_protection_panel.dart';
import '../../feed/providers/feed_provider.dart';

/// 공개 범위·시청 기록·탐색 크롬 등 프라이버시
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _savingPublic = false;
  bool _clearing = false;
  bool _clearingYoutubeHistory = false;

  Future<void> _setIslandPublic(bool value) async {
    if (!Env.isSupabaseConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인·서버 연동 후 섬 공개 설정을 바꿀 수 있어요')),
      );
      return;
    }
    final profile = ref.read(currentUserProvider).value;
    if (profile == null) return;
    setState(() => _savingPublic = true);
    try {
      await ref
          .read(authRepoProvider)
          .updateProfile(profile.copyWith(isPublic: value));
      ref.invalidate(currentUserProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value ? '섬이 탐색에 공개됩니다' : '섬이 비공개입니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _savingPublic = false);
    }
  }

  Future<void> _clearWebSessions() async {
    setState(() => _clearing = true);
    try {
      await IsleWebSessionPersistenceService.clearStored();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('브라우저 세션·쿠키를 삭제했어요')),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _clearYoutubeWatchHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('MOA 시청 기록을 삭제할까요?'),
        content: const Text('실제 재생 기록만 삭제합니다. 나중에 볼 목록은 유지됩니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearingYoutubeHistory = true);
    try {
      final removed = await YoutubeWatchHistoryService.clearHistory();
      await ref.read(personalLibraryProvider.notifier).reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('시청 기록 $removed개를 삭제했어요')),
        );
      }
    } finally {
      if (mounted) setState(() => _clearingYoutubeHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: const IsleAppBar(title: '공개 · 프라이버시'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '데이터는 기기·iCloud 백업 폴더에 저장됩니다. 서버에는 로그인 시 프로필·섬 공개만 올라갑니다.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('개인정보처리방침', style: IsleText.body()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/privacy-policy'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('계정·데이터 삭제', style: IsleText.body()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/account-deletion'),
          ),
          const Divider(height: 32),
          Text('섬 · 탐색', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          profileAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => Text('프로필을 불러오지 못했어요',
                style: IsleText.caption(color: IsleColors.muted)),
            data: (UserProfile? profile) {
              final isPublic = profile?.isPublic ?? true;
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('다른 사람 섬에 내 섬 보이기', style: IsleText.body()),
                subtitle: Text(
                  isPublic ? '탐색·다른 사람 섬 둘러보기에 표시' : '나만 볼 수 있음',
                  style: IsleText.caption(color: IsleColors.muted),
                ),
                value: isPublic,
                onChanged: _savingPublic ? null : _setIslandPublic,
              );
            },
          ),
          const Divider(height: 32),
          Text('유튜브 · 탐색', style: IsleText.subtitle()),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('시청 기록 추적', style: IsleText.body()),
            subtitle: Text('실제로 재생된 시간만 기기에 기록해 영상 추천에 사용합니다.',
                style: IsleText.caption(color: IsleColors.muted)),
            value: IsleUserDefaults.trackYoutubeWatchHistory,
            onChanged: (v) async {
              await IsleUserDefaults.setTrackYoutubeWatchHistory(v);
              setState(() {});
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed:
                  _clearingYoutubeHistory ? null : _clearYoutubeWatchHistory,
              icon: _clearingYoutubeHistory
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_outline),
              label: const Text('MOA 시청 기록 모두 삭제'),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('탐색 브라우저 다크 크롬', style: IsleText.body()),
            value: IsleUserDefaults.explorerChromeDark,
            onChanged: (v) async {
              await IsleUserDefaults.setExplorerChromeDark(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('피드에서 차단한 항목 숨기기', style: IsleText.body()),
            value: IsleUserDefaults.hideBlockedInFeed,
            onChanged: (v) async {
              await IsleUserDefaults.setHideBlockedInFeed(v);
              ref.invalidate(feedProvider);
              setState(() {});
            },
          ),
          Text('성인 보호', style: IsleText.subtitle()),
          const SizedBox(height: 6),
          Text(
            '보호 필터와 동일 — ${AdultProtectionService.tier.labelKo} '
            '(기본=SafeSearch · 강화=400+ 규칙)',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 10),
          AdultProtectionPanel(compact: true, onChanged: () => setState(() {})),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push('/home/sns/protection-filter'),
            child: const Text('보호 필터에서 자세히'),
          ),
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Google 검색 — 키워드 숨김', style: IsleText.body()),
            value: IsleUserDefaults.blockGoogleSearchKeywords,
            onChanged: (v) async {
              await IsleUserDefaults.setBlockGoogleSearchKeywords(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Google 검색 — URL 숨김', style: IsleText.body()),
            value: IsleUserDefaults.blockGoogleSearchUrls,
            onChanged: (v) async {
              await IsleUserDefaults.setBlockGoogleSearchUrls(v);
              setState(() {});
            },
          ),
          const Divider(height: 32),
          Text('WebView 로그인', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          Text(AppLegalInfo.sessionCookieNotice,
              style: IsleText.caption(color: IsleColors.muted)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _clearing ? null : _clearWebSessions,
            icon: _clearing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cookie_outlined),
            label: const Text('세션·쿠키 삭제'),
          ),
          const SizedBox(height: 16),
          Text(AppLegalInfo.apiKeyNotice,
              style: IsleText.caption(color: IsleColors.muted)),
          const SizedBox(height: 12),
          Text(AppLegalInfo.thirdPartyDisclaimer,
              style: IsleText.caption(color: IsleColors.muted)),
        ],
      ),
    );
  }
}
