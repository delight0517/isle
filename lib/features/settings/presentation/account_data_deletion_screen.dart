import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_legal_info.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/env.dart';
import '../../../core/services/account_data_deletion_service.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../auth/providers/auth_provider.dart';

/// 계정·로컬 데이터 삭제 (Play Data deletion 요구).
class AccountDataDeletionScreen extends ConsumerStatefulWidget {
  const AccountDataDeletionScreen({super.key});

  @override
  ConsumerState<AccountDataDeletionScreen> createState() =>
      _AccountDataDeletionScreenState();
}

class _AccountDataDeletionScreenState extends ConsumerState<AccountDataDeletionScreen> {
  bool _busy = false;

  Future<void> _confirmAndDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계정·데이터 삭제'),
        content: Text(
          Env.isSupabaseConfigured
              ? '서버 프로필·로그인 세션·기기의 WebView 쿠키·암호화 저장 데이터를 삭제합니다.\n'
                  '인증 계정 완전 삭제가 필요하면 이메일 요청도 함께 안내해 드려요.'
              : '로그인 없이 사용 중이어도 기기에 저장된 세션·민감 데이터를 삭제합니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: IsleColors.danger),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (Env.isSupabaseConfigured) {
        await ref.read(authRepoProvider).deleteAccountAndLocalData();
      } else {
        await AccountDataDeletionService.clearLocalSensitiveData();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제를 완료했어요')),
      );
      if (Env.isSupabaseConfigured) context.go('/login');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearSessionsOnly() async {
    setState(() => _busy = true);
    try {
      await AccountDataDeletionService.clearLocalSensitiveData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('브라우저 세션·쿠키를 삭제했어요')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IsleAppBar(title: '계정 · 데이터 삭제'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Play 스토어 정책에 따라 계정·데이터 삭제를 요청할 수 있어요.',
            style: IsleText.body(color: IsleColors.muted),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('브라우저 세션·쿠키 삭제', style: IsleText.subtitle()),
            subtitle: Text(
              AppLegalInfo.sessionCookieNotice,
              style: IsleText.caption(color: IsleColors.muted),
            ),
            trailing: _busy
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(onPressed: _clearSessionsOnly, child: const Text('삭제')),
          ),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('계정·로컬 데이터 삭제', style: IsleText.subtitle()),
            subtitle: Text(
              '로그인 계정(있을 때) · 프로필 · 세션 쿠키 · 암호화 저장소',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            trailing: FilledButton(
              onPressed: _busy ? null : _confirmAndDeleteAccount,
              style: FilledButton.styleFrom(backgroundColor: IsleColors.danger),
              child: const Text('삭제'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => launchUrl(AppLegalInfo.accountDeletionMailto),
            icon: const Icon(Icons.mail_outline),
            label: Text('이메일로 삭제 요청 (${AppLegalInfo.supportEmail})'),
          ),
        ],
      ),
    );
  }
}
