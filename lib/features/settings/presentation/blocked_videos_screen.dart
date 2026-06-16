import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/block/rule_removal_lock.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/youtube/content_filter_store.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../../shared/widgets/rule_removal_lock_controls.dart';

class BlockedVideosScreen extends ConsumerStatefulWidget {
  const BlockedVideosScreen({super.key});

  @override
  ConsumerState<BlockedVideosScreen> createState() => _BlockedVideosScreenState();
}

class _BlockedVideosScreenState extends ConsumerState<BlockedVideosScreen> {
  @override
  void initState() {
    super.initState();
    RuleRemovalLock.finalizeExpiredUnlock();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(blockedVideosProvider);

    return Scaffold(
      appBar: const IsleAppBar(title: '숨긴 영상'),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: RuleRemovalLockControls(compact: true),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text('숨긴 영상 없음', style: IsleText.body(color: IsleColors.muted)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (_, i) {
                      final v = list[i];
                      return ListTile(
                        leading: const Icon(Icons.movie_filter_outlined, color: IsleColors.ocean500),
                        title: Text(v.videoId, style: IsleText.body(), maxLines: 1),
                        subtitle: v.sourceUrl != null && v.sourceUrl!.isNotEmpty
                            ? Text(v.sourceUrl!, style: IsleText.caption(color: IsleColors.muted), maxLines: 1)
                            : null,
                        trailing: TextButton(
                          onPressed: () {
                            if (RuleRemovalLock.removalBlocked) {
                              showRuleRemovalBlockedSnackBar(context);
                              return;
                            }
                            ref.read(blockedVideosProvider.notifier).removeVideo(v.videoId);
                          },
                          child: const Text('해제'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
