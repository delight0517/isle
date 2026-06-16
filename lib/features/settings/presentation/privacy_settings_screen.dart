import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/env.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../auth/data/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 공개 범위·시청 기록·탐색 크롬 등 프라이버시
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _savingPublic = false;

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
      await ref.read(authRepoProvider).updateProfile(profile.copyWith(isPublic: value));
      ref.invalidate(currentUserProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value ? '섬이 탐색에 공개됩니다' : '섬이 비공개입니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _savingPublic = false);
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
          const SizedBox(height: 20),
          Text('섬 · 탐색', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          profileAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => Text('프로필을 불러오지 못했어요', style: IsleText.caption(color: IsleColors.muted)),
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
            subtitle: Text('WebView 시청 → 피드·통계 반영', style: IsleText.caption(color: IsleColors.muted)),
            value: IsleUserDefaults.trackYoutubeWatchHistory,
            onChanged: (v) async {
              await IsleUserDefaults.setTrackYoutubeWatchHistory(v);
              setState(() {});
            },
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
              setState(() {});
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('안전 모드', style: IsleText.body()),
            subtitle: Text(
              '성인 사이트 차단 · SafeSearch · 유튜브 제한 모드',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            value: IsleUserDefaults.contentSafetyEnabled,
            onChanged: (v) async {
              await IsleUserDefaults.setContentSafetyEnabled(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Google 검색 키워드 숨김', style: IsleText.body()),
            subtitle: Text(
              'Safari(구글) 검색 결과에서 등록한 키워드 포함 카드 숨김',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            value: IsleUserDefaults.blockGoogleSearchKeywords,
            onChanged: (v) async {
              await IsleUserDefaults.setBlockGoogleSearchKeywords(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Google 검색 YouTube 미리보기 차단', style: IsleText.body()),
            subtitle: Text(
              'Safari(구글) 검색 결과에서 영상이 바로 재생되지 않게',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            value: IsleUserDefaults.blockGoogleYoutubeInlinePreview,
            onChanged: (v) async {
              await IsleUserDefaults.setBlockGoogleYoutubeInlinePreview(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('YouTube 공유 → 몰입 모드', style: IsleText.body()),
            subtitle: Text(
              '다른 앱에서 공유한 링크를 요약 먼저 보기로 열기',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            value: IsleUserDefaults.youtubeSharesUseFocusMode,
            onChanged: (v) async {
              await IsleUserDefaults.setYoutubeSharesUseFocusMode(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('YouTube 공유 → 음성 모드', style: IsleText.body()),
            subtitle: Text(
              'Safari·YouTube 공유 링크를 듣기 전용으로 열기',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            value: IsleUserDefaults.youtubeSharesUsePodcastMode,
            onChanged: (v) async {
              await IsleUserDefaults.setYoutubeSharesUsePodcastMode(v);
              setState(() {});
            },
          ),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.save_alt, color: IsleColors.ocean700),
            title: Text('데이터 백업', style: IsleText.body()),
            subtitle: Text('백업 코드 · iCloud 폴더', style: IsleText.caption(color: IsleColors.muted)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/backup'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bar_chart_outlined, color: IsleColors.ocean700),
            title: Text('플랫폼 사용 시간', style: IsleText.body()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/platform-stats'),
          ),
        ],
      ),
    );
  }
}
