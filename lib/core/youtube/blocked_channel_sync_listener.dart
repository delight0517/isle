import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/isle_survival_backup_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'blocked_channel_store.dart';

/// 로그인·앱 시작 시 차단 목록 클라우드 병합
class BlockedChannelSyncListener extends ConsumerStatefulWidget {
  const BlockedChannelSyncListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BlockedChannelSyncListener> createState() => _BlockedChannelSyncListenerState();
}

class _BlockedChannelSyncListenerState extends ConsumerState<BlockedChannelSyncListener> {
  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (prev, next) {
      final was = prev?.value?.id;
      final now = next.value?.id;
      if (now != null && was != now) {
        _sync();
      }
    });
    return widget.child;
  }

  Future<void> _sync() async {
    await ref.read(blockedChannelsProvider.notifier).syncWithCloud();
    await IsleSurvivalBackupService.syncNow();
  }
}
