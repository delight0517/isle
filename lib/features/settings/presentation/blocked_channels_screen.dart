import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/youtube_paste_resolver.dart';
import '../../../core/youtube/blocked_channel_store.dart';
import '../../../core/youtube/content_filter_store.dart';
import '../../../core/youtube/models/blocked_channel.dart';
import '../../../core/block/rule_removal_lock.dart';
import '../../../shared/widgets/rule_removal_lock_controls.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../../shared/widgets/isle_sheet.dart';
import '../../auth/presentation/widgets/google_account_sync_card.dart';
import '../../feed/providers/feed_provider.dart';

class BlockedChannelsScreen extends ConsumerStatefulWidget {
  const BlockedChannelsScreen({super.key});

  @override
  ConsumerState<BlockedChannelsScreen> createState() => _BlockedChannelsScreenState();
}

class _BlockedChannelsScreenState extends ConsumerState<BlockedChannelsScreen> {
  @override
  void initState() {
    super.initState();
    RuleRemovalLock.finalizeExpiredUnlock();
  }

  @override
  Widget build(BuildContext context) {
    final blocked = ref.watch(blockedChannelsProvider);

    return Scaffold(
      appBar: IsleAppBar(
        title: '차단한 채널',
        actions: [
          IconButton(
            tooltip: '목록 붙여넣기',
            icon: const Icon(Icons.playlist_add),
            onPressed: () => _showBulkBlockSheet(context, ref),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GoogleAccountSyncCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: const RuleRemovalLockControls(compact: true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '가능: 채널 전체 숨기기, 특정 영상 숨기기. '
              '불가: YouTube 앱/사이트의 원본 검색결과 자체를 지우기(앱 내부 피드만 필터링).',
              style: IsleText.caption(color: IsleColors.muted),
            ),
          ),
          Expanded(
            child: blocked.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '차단한 채널이 없습니다.\n피드에서 오른쪽으로 스와이프하거나\n유튜브 브라우저에서 추가하세요.',
                  textAlign: TextAlign.center,
                  style: IsleText.body(color: IsleColors.muted),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: blocked.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (ctx, i) => _BlockedTile(channel: blocked[i]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBulkBlockSheet(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    var running = false;
    await showIsleModalSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('유튜브 목록 일괄 차단', style: IsleText.subtitle()),
                  const SizedBox(height: 8),
                  Text(
                    '한 줄에 1개 링크를 붙여넣으세요.\n채널 링크는 채널 전체, watch 링크는 해당 영상이 차단됩니다.',
                    style: IsleText.caption(color: IsleColors.muted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    minLines: 8,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'youtube.com/...\nyoutube.com/watch?v=...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: running
                        ? null
                        : () async {
                            setLocal(() => running = true);
                            final result = await _bulkApplyFromLines(ref, ctrl.text);
                            ref.invalidate(feedProvider);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result)),
                              );
                            }
                          },
                    icon: running
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.shield_outlined),
                    label: Text(running ? '적용 중...' : '일괄 적용'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    ctrl.dispose();
  }

  Future<String> _bulkApplyFromLines(WidgetRef ref, String raw) async {
    final lines = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '입력된 링크가 없습니다.';

    var channelAdded = 0;
    var videoAdded = 0;
    var keywordAdded = 0;
    var failed = 0;

    for (final line in lines) {
      final normalized = line.startsWith('http') ? line : 'https://$line';
      try {
        final info = await YoutubePasteResolver.resolve(normalized);
        var touched = false;
        if (info.canBlockChannel) {
          final id = info.channelIdForStore.trim();
          final name = (info.channelName ?? '').trim();
          if (id.isNotEmpty || name.isNotEmpty) {
            await ref.read(blockedChannelsProvider.notifier).blockChannel(
                  channelId: id.isNotEmpty ? id : name,
                  channelName: name.isNotEmpty ? name : id,
                );
            channelAdded++;
            touched = true;
          }
        }
        if (info.canBlockThisVideo) {
          await ref
              .read(blockedVideosProvider.notifier)
              .addVideo(info.videoId!, sourceUrl: info.sourceUrl ?? normalized);
          videoAdded++;
          touched = true;
        }
        if (!touched) {
          final fallback = _extractFallbackKeyword(normalized);
          if (fallback != null) {
            await ref.read(blockedKeywordsProvider.notifier).add(fallback);
            keywordAdded++;
          } else {
            failed++;
          }
        }
      } catch (_) {
        final fallback = _extractFallbackKeyword(normalized);
        if (fallback != null) {
          await ref.read(blockedKeywordsProvider.notifier).add(fallback);
          keywordAdded++;
        } else {
          failed++;
        }
      }
    }

    return '적용 완료: 채널 $channelAdded개, 영상 $videoAdded개, 키워드 $keywordAdded개, 실패 $failed개';
  }

  String? _extractFallbackKeyword(String input) {
    final uri = Uri.tryParse(input);
    if (uri == null) return null;
    final segs = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    if (segs.isEmpty) return null;
    final first = segs.first;
    final lower = first.toLowerCase();
    if (lower == 'watch' || lower == 'shorts' || lower == 'channel' || lower == 'c') {
      return null;
    }
    final cleaned = first.replaceAll('@', '').trim();
    if (cleaned.isEmpty) return null;
    return cleaned;
  }
}

class _BlockedTile extends ConsumerWidget {
  final BlockedChannel channel;

  const _BlockedTile({required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: IsleColors.ocean100,
        child: Icon(Icons.block, color: IsleColors.danger, size: 20),
      ),
      title: Text(channel.channelName, style: IsleText.body()),
      subtitle: Text(
        channel.channelId.isNotEmpty ? channel.channelId : 'ID 없음',
        style: IsleText.caption(color: IsleColors.muted),
      ),
      trailing: TextButton(
        onPressed: () async {
          if (RuleRemovalLock.removalBlocked) {
            showRuleRemovalBlockedSnackBar(context);
            return;
          }
          await ref.read(blockedChannelsProvider.notifier).unblock(
                channel.channelId.isNotEmpty ? channel.channelId : channel.channelName,
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${channel.channelName} 차단을 해제했습니다.')),
            );
          }
        },
        child: const Text('해제'),
      ),
    );
  }
}
