import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/isle_app_log_service.dart';
import '../core/services/isle_survival_backup_service.dart';
import '../features/auth/providers/auth_provider.dart';
import '../core/youtube/blocked_channel_store.dart';

/// 로그인 성공 시 차단 채널 클라우드 병합
class AuthCallbackListener extends ConsumerWidget {
  const AuthCallbackListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (prev, next) {
      final was = prev?.value?.id;
      final now = next.value?.id;
      if (now != null && was != now) {
        IsleAppLogService.log('Signed in → cloud merge + local survival backup');
        ref.read(blockedChannelsProvider.notifier).syncWithCloud();
        unawaited(IsleSurvivalBackupService.syncNow());
      }
    });
    return child;
  }
}
