import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/localization/app_strings.dart';
import '../providers/explore_provider.dart';

class ChatGateScreen extends ConsumerWidget {
  final String peerUserId;
  final String peerName;
  const ChatGateScreen({
    super.key,
    required this.peerUserId,
    required this.peerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final canOpenAsync = ref.watch(canOpenChatProvider(peerUserId));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(s.t('request_inbox'), style: IsleText.subtitle()),
      ),
      body: canOpenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString(), style: IsleText.caption(color: IsleColors.muted))),
        data: (canOpen) {
          if (!canOpen) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${s.t('chat_locked', args: {'name': peerName})}\n${s.t('chat_locked_desc')}',
                  textAlign: TextAlign.center,
                  style: IsleText.body(color: IsleColors.muted),
                ),
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mark_chat_read_outlined, size: 54, color: IsleColors.ocean500),
                  const SizedBox(height: 12),
                  Text(s.t('chat_open', args: {'name': peerName}), style: IsleText.subtitle()),
                  const SizedBox(height: 8),
                  Text(
                    s.t('chat_open_desc'),
                    textAlign: TextAlign.center,
                    style: IsleText.caption(color: IsleColors.muted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
