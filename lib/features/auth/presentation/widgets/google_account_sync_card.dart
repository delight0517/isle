import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/env.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/youtube/blocked_channel_store.dart';
import '../../providers/auth_provider.dart';

/// 차단 채널 화면·설정 — Google 로그인 + 클라우드 동기화 상태
class GoogleAccountSyncCard extends ConsumerWidget {
  const GoogleAccountSyncCard({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final blocked = ref.watch(blockedChannelsProvider);
    final syncOn = IsleUserDefaults.syncBlockedChannelsToCloud;
    final supabaseOk = Env.isSupabaseConfigured;

    return Container(
      margin: compact ? EdgeInsets.zero : const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: supabaseOk ? IsleColors.ocean100 : IsleColors.sand100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IsleColors.ocean300.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.network(
                'https://www.google.com/favicon.ico',
                width: 22,
                height: 22,
                errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Google 계정 · 차단 목록',
                  style: IsleText.subtitle(color: IsleColors.ocean900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!supabaseOk)
            Text(
              '클라우드 저장에는 Supabase 서버 설정이 필요합니다 (1회). '
              '지금은 이 기기에만 ${blocked.length}개 저장됩니다.',
              style: IsleText.caption(color: IsleColors.muted),
            )
          else if (user == null)
            Text(
              'Google로 로그인하면 「싫어한다고 표시한 채널」 목록이 '
              '계정에 저장되어 다른 기기에서도 불러올 수 있습니다.',
              style: IsleText.caption(color: IsleColors.muted),
            )
          else
            Text(
              '${user.email ?? 'Google 계정'} · 차단 ${blocked.length}개 '
              '${syncOn ? '· 클라우드 동기화 켜짐' : '· 동기화 꺼짐'}',
              style: IsleText.caption(color: IsleColors.ocean700),
            ),
          if (supabaseOk) ...[
            const SizedBox(height: 12),
            if (user == null)
              FilledButton.icon(
                onPressed: () => _signInGoogle(context, ref),
                icon: const Icon(Icons.login),
                label: const Text('Google로 로그인'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: IsleColors.ocean900,
                ),
              )
            else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('차단 목록 클라우드 동기화'),
                subtitle: const Text('차단·해제 시 서버에 반영'),
                value: syncOn,
                onChanged: (v) async {
                  await IsleUserDefaults.setSyncBlockedChannelsToCloud(v);
                  if (v) {
                    await ref.read(blockedChannelsProvider.notifier).syncWithCloud();
                  }
                  ref.invalidate(blockedChannelsProvider);
                },
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => ref.read(blockedChannelsProvider.notifier).syncWithCloud(),
                    child: const Text('지금 동기화'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => ref.read(authRepoProvider).signOut(),
                    child: const Text('로그아웃'),
                  ),
                ],
              ),
            ],
          ],
          if (!compact)
            TextButton(
              onPressed: () => _showSetupSheet(context),
              child: const Text('서버 설정이 뭔가요?'),
            ),
        ],
      ),
    );
  }

  Future<void> _signInGoogle(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepoProvider).signInWithGoogle();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google 로그인 처리 중… 브라우저에서 돌아오면 동기화됩니다')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showSetupSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('필요한 설정 (1회)', style: IsleText.subtitle()),
            const SizedBox(height: 12),
            const _SetupStep(n: '1', text: 'Supabase 프로젝트 생성 → env.dart에 URL·anon key'),
            const _SetupStep(n: '2', text: 'Authentication → Google 켜기 (Client ID/Secret)'),
            const _SetupStep(n: '3', text: 'Redirect URL: isle://login-callback'),
            const _SetupStep(n: '4', text: 'SQL: blocked_channels 테이블 (user_id, channel_id, …)'),
            const _SetupStep(
              n: '5',
              text: 'Android: SHA-1 + 패키지 com.isle.app → googleWebClientId (Supabase용 Web ID)',
            ),
            const _SetupStep(n: '6', text: 'iOS: googleIosClientId + Info.plist URL scheme'),
            const SizedBox(height: 12),
            Text(
              '중간 난이도입니다. YouTube API용 Google 로그인과는 별개 설정이에요. '
              '완료 후 「Google로 로그인」만 누르면 차단 목록이 계정에 붙습니다.',
              style: IsleText.caption(color: IsleColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.n, required this.text});

  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$n.', style: IsleText.body(color: IsleColors.ocean500)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: IsleText.body())),
        ],
      ),
    );
  }
}
