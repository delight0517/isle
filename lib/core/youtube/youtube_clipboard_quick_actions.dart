import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../navigation/isle_navigation.dart';
import '../navigation/share_link_router.dart';
import '../services/isle_user_defaults.dart';
import '../utils/youtube_paste_resolver.dart';
import '../../features/feed/providers/feed_provider.dart';
import '../../shared/widgets/isle_sheet.dart';
import 'blocked_channel_store.dart';
import 'content_filter_store.dart';
import 'youtube_clipboard_watch.dart';

/// 클립보드 YouTube 링크 → 열기 · 채널 숨기기 · 영상만 숨기기 (인앱·복귀 공통)
class YoutubeClipboardQuickActions {
  YoutubeClipboardQuickActions._();

  static bool _offering = false;

  static bool sameTarget(String? a, String? b) {
    if (a == null || b == null) return false;
    final na = YoutubeClipboardWatch.normalizeUrl(a);
    final nb = YoutubeClipboardWatch.normalizeUrl(b);
    return na != null && nb == na;
  }

  /// [onOpenInPlace] — WebView 안이면 현재 탭에서 열기. null이면 라우트 push.
  static Future<void> maybeOffer(
    BuildContext context, {
    String? currentPageUrl,
    Future<void> Function(String url)? onOpenInPlace,
  }) async {
    if (!IsleUserDefaults.youtubeClipboardLaunchOnResume) return;
    if (_offering) return;
    _offering = true;
    try {
      final url = await YoutubeClipboardWatch.readClipboardUrl();
      if (url == null) return;
      if (!context.mounted) return;

      final last = IsleUserDefaults.lastClipboardYoutubeOfferUrl;
      if (last == url) return;
      await IsleUserDefaults.setLastClipboardYoutubeOfferUrl(url);

      final info = await YoutubePasteResolver.resolve(url);
      if (!context.mounted) return;
      if (!info.valid) return;

      final alreadyHere = onOpenInPlace != null && sameTarget(url, currentPageUrl);

      await showYoutubeClipboardQuickSheet(
        context,
        url: url,
        info: info,
        showOpen: onOpenInPlace == null || !alreadyHere,
        onOpen: () async {
          if (onOpenInPlace != null) {
            await onOpenInPlace(url);
          } else {
            final route = ShareLinkRouter.inAppRouteForUrl(url);
            if (route != null) IsleNavigation.push(route);
          }
        },
      );
    } finally {
      _offering = false;
    }
  }
}

Future<void> showYoutubeClipboardQuickSheet(
  BuildContext context, {
  required String url,
  required YoutubePasteInfo info,
  required bool showOpen,
  required Future<void> Function() onOpen,
}) {
  return showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => _YoutubeClipboardQuickSheet(
      url: url,
      info: info,
      showOpen: showOpen,
      onOpen: onOpen,
    ),
  );
}

class _YoutubeClipboardQuickSheet extends ConsumerWidget {
  const _YoutubeClipboardQuickSheet({
    required this.url,
    required this.info,
    required this.showOpen,
    required this.onOpen,
  });

  final String url;
  final YoutubePasteInfo info;
  final bool showOpen;
  final Future<void> Function() onOpen;

  Future<void> _blockChannel(BuildContext context, WidgetRef ref) async {
    final id = info.channelIdForStore;
    final name = (info.channelName ?? '').trim();
    if (id.isEmpty && name.isEmpty) return;
    await ref.read(blockedChannelsProvider.notifier).blockChannel(
          channelId: id.isNotEmpty ? id : name,
          channelName: name.isNotEmpty ? name : id,
        );
    ref.invalidate(feedProvider);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${name.isNotEmpty ? name : id}」 채널을 숨겼어요')),
      );
    }
  }

  Future<void> _blockVideo(BuildContext context, WidgetRef ref) async {
    final vid = info.videoId;
    if (vid == null || vid.length != 11) return;
    await ref.read(blockedVideosProvider.notifier).addVideo(vid, sourceUrl: info.sourceUrl);
    ref.invalidate(feedProvider);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 영상만 숨겼어요')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final title = (info.title ?? '').trim();
    final channel = (info.channelName ?? '').trim();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('클립보드 YouTube 링크', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          if (title.isNotEmpty)
            Text(title, style: IsleText.body().copyWith(fontWeight: FontWeight.w600), maxLines: 2),
          if (channel.isNotEmpty)
            Text('채널: $channel', style: IsleText.caption(color: IsleColors.muted)),
          const SizedBox(height: 16),
          if (showOpen)
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await onOpen();
              },
              icon: Icon(
                IsleUserDefaults.youtubeSharesUsePodcastMode
                    ? Icons.headphones
                    : Icons.play_circle_outline,
              ),
              label: Text(
                IsleUserDefaults.youtubeSharesUsePodcastMode
                    ? '음성 모드로 열기'
                    : 'Isle에서 열기',
              ),
            ),
          if (showOpen && (info.canBlockChannel || info.canBlockThisVideo)) const SizedBox(height: 10),
          if (info.canBlockChannel)
            FilledButton.icon(
              onPressed: () => _blockChannel(context, ref),
              style: FilledButton.styleFrom(backgroundColor: IsleColors.danger),
              icon: const Icon(Icons.block),
              label: const Text('이 채널 숨기기'),
            ),
          if (info.canBlockChannel && info.canBlockThisVideo) const SizedBox(height: 10),
          if (info.canBlockThisVideo)
            OutlinedButton.icon(
              onPressed: () => _blockVideo(context, ref),
              icon: const Icon(Icons.videocam_off_outlined),
              label: const Text('이 영상만 숨기기'),
            ),
          if (!info.canBlockChannel && !info.canBlockThisVideo && !showOpen)
            Text(
              '숨길 수 있는 정보가 부족해요.',
              style: IsleText.caption(color: IsleColors.muted),
            ),
        ],
      ),
    );
  }
}
