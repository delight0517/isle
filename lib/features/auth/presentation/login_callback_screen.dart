import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../providers/auth_provider.dart';
import '../../../core/youtube/blocked_channel_store.dart';

/// `isle://login-callback` — Google OAuth 복귀 처리
class LoginCallbackScreen extends ConsumerStatefulWidget {
  const LoginCallbackScreen({super.key, required this.uri, this.lightMode = false});

  final Uri uri;
  final bool lightMode;

  @override
  ConsumerState<LoginCallbackScreen> createState() => _LoginCallbackScreenState();
}

class _LoginCallbackScreenState extends ConsumerState<LoginCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
  }

  Future<void> _finish() async {
    final ok = await ref.read(authRepoProvider).handleAuthCallbackUri(widget.uri);
    if (ok) {
      await ref.read(blockedChannelsProvider.notifier).syncWithCloud();
    }
    if (!mounted) return;
    final uid = ref.read(authRepoProvider).currentUser?.id;
    if (uid != null) {
      final isNew = await ref.read(authRepoProvider).isNewUser(uid);
      if (!mounted) return;
      if (widget.lightMode) {
        context.go('/light/youtube');
      } else {
        context.go(isNew ? '/onboarding' : '/feed');
      }
    } else {
      context.go(widget.lightMode ? '/login' : '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IsleColors.ocean900,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: IsleColors.gold500),
            const SizedBox(height: 16),
            Text('Google 로그인 연결 중…', style: IsleText.body(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
