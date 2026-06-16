import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/isle_routes.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_release_info.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/env.dart';
import '../../auth/presentation/widgets/google_account_sync_card.dart';
import '../../auth/providers/auth_provider.dart';

/// Light 설정 — 로그인·한도·백업만
class LightSettingsScreen extends ConsumerWidget {
  const LightSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('설정', style: IsleText.subtitle(color: IsleColors.ocean900)),
        centerTitle: false,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _body(context, ref, displayName: '사용자', username: 'isle'),
        data: (profile) => _body(
          context,
          ref,
          displayName: profile?.displayName ?? '로컬 사용자',
          username: profile?.username ?? 'local',
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref, {
    required String displayName,
    required String username,
  }) {
    return ListView(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: IsleColors.ocean100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: IsleColors.ocean500,
                child: Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: IsleText.subtitle()),
                    Text('@$username', style: IsleText.caption(color: IsleColors.muted)),
                    const SizedBox(height: 4),
                    Text(
                      AppReleaseInfo.lightLabel,
                      style: IsleText.caption(color: IsleColors.ocean700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (Env.isSupabaseConfigured) ...[
          const GoogleAccountSyncCard(),
          ListTile(
            leading: const Icon(Icons.login, color: IsleColors.ocean700),
            title: const Text('계정 로그인'),
            subtitle: const Text('이메일 · Google — 차단 목록 클라우드'),
            trailing: const Icon(Icons.chevron_right, color: IsleColors.muted),
            onTap: () => context.push('/login'),
          ),
        ],
        if (!Env.isSupabaseConfigured)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '로컬 모드 — 차단 목록은 이 기기에만 저장됩니다. '
              'Google·클라우드 동기화는 Supabase 설정 후 사용할 수 있어요.',
              style: IsleText.caption(color: IsleColors.muted),
            ),
          ),
        _section('유튜브'),
        _tile(Icons.spa_outlined, '3초 몰입 모드', '검색 · 요약 먼저 · 알고리즘 제로', () {
          context.push('/youtube-focus');
        }),
        _tile(Icons.timer_outlined, '시청 한도', '일일 분 제한', () {
          context.push(IsleRoutes.youtubeLimits);
        }),
        _tile(Icons.tune, '필터 옵션', '숨김 동작', () {
          context.push('/light/settings/youtube-filter');
        }),
        _section('데이터'),
        _tile(Icons.save_alt, '백업 · 복원', '재설치 후에도 차단 유지', () {
          context.push('/light/settings/backup');
        }),
        if (Env.isSupabaseConfigured) ...[
          const Divider(indent: 16),
          _tile(Icons.logout, '로그아웃', null, () async {
            await ref.read(authRepoProvider).signOut();
            if (context.mounted) context.go('/light/youtube');
          }, color: IsleColors.danger),
        ],
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Isle Light는 유튜브 시청·차단·스케줄에 집중한 버전입니다. '
            'AI 요약·피드·섬은 iOS 전체 앱에서 이용할 수 있어요.',
            style: IsleText.caption(color: IsleColors.muted),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Text(
          title,
          style: IsleText.caption(color: IsleColors.muted).copyWith(fontWeight: FontWeight.w600),
        ),
      );

  Widget _tile(
    IconData icon,
    String title,
    String? subtitle,
    VoidCallback onTap, {
    Color? color,
  }) =>
      ListTile(
        leading: Icon(icon, color: color ?? IsleColors.ocean700, size: 22),
        title: Text(title, style: IsleText.body(color: color)),
        subtitle: subtitle == null ? null : Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
        trailing: color == null ? const Icon(Icons.chevron_right, color: IsleColors.muted) : null,
        onTap: onTap,
      );
}
