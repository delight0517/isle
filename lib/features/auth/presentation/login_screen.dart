import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/env.dart';
import '../../../core/focus/isle_product_focus.dart';
import '../../../core/services/pending_share_navigation.dart';
import '../providers/auth_provider.dart';
import 'widgets/google_account_sync_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.lightMode = false});

  final bool lightMode;
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInGoogle() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepoProvider).signInWithGoogle();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('브라우저에서 Google 로그인 후 앱으로 돌아오면 연결됩니다'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepoProvider);
      if (_isLogin) {
        await repo.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
      } else {
        await repo.signUpWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
      }
      if (mounted) {
        final uid = ref.read(authRepoProvider).currentUser?.id;
        if (widget.lightMode) {
          if (mounted) context.go('/light/youtube');
          return;
        }
        if (uid == null) {
          if (mounted) {
            context.go(IsleProductFocus.enabled ? '/home/block' : '/feed');
          }
          PendingShareNavigation.tryNavigateFromStoredPending();
          return;
        }
        final isNew = await repo.isNewUser(uid);
        if (mounted) {
          if (isNew) {
            context.go('/onboarding');
          } else {
            context.go(IsleProductFocus.enabled ? '/home/block' : '/feed');
            PendingShareNavigation.tryNavigateFromStoredPending();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IsleColors.ocean900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.cabin, size: 72, color: IsleColors.gold500)
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text(
                widget.lightMode ? 'ISLE LIGHT' : 'ISLE',
                style: IsleText.display(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                widget.lightMode
                    ? '유튜브 · 차단 · 스케줄'
                    : 'Your island. Your algorithm.',
                style: IsleText.body(color: IsleColors.sand500),
              ),
              const Spacer(),
              if (Env.isSupabaseConfigured) ...[
                const GoogleAccountSyncCard(compact: true),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _signInGoogle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Google로 로그인 (차단 목록 저장)'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('또는 이메일', style: IsleText.caption(color: IsleColors.sand500)),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Supabase 미설정 — 로그인 없이 로컬만 사용',
                    textAlign: TextAlign.center,
                    style: IsleText.caption(color: IsleColors.sand500),
                  ),
                ),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: IsleText.body(color: IsleColors.ocean900),
                decoration: _inputDeco('이메일'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                style: IsleText.body(color: IsleColors.ocean900),
                decoration: _inputDeco('비밀번호'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IsleColors.gold500,
                    foregroundColor: IsleColors.ocean900,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Text(
                          _isLogin ? '로그인' : '회원가입',
                          style: IsleText.subtitle(color: IsleColors.ocean900),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin ? '계정이 없으신가요? 회원가입' : '이미 계정이 있으신가요? 로그인',
                  style: IsleText.caption(color: IsleColors.sand500),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: IsleColors.sand100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
