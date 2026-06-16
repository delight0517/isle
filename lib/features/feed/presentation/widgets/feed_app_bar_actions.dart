import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/focus/isle_product_focus.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/youtube/youtube_clipboard_watch.dart';
import 'add_feed_subscription_sheet.dart';
import 'block_from_link_sheet.dart';
import 'feed_platform_picker_sheet.dart';
import 'keyword_filter_sheet.dart';

/// 피드 상단 — 핵심(유튜브·검색)만 노출, 필터는 메뉴로 [Vantage]
class FeedAppBarActions extends ConsumerWidget {
  const FeedAppBarActions({super.key, required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = IsleProductFocus.hideSecondaryUi;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact)
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined, color: IsleColors.ocean900),
            tooltip: '구독 추가',
            onPressed: () => showAddFeedSubscriptionSheet(context, ref),
          ),
        IconButton(
          icon: const Icon(Icons.search, color: IsleColors.ocean900),
          tooltip: '검색',
          onPressed: onSearch,
        ),
        IconButton(
          icon: const Icon(Icons.content_paste_go, color: Color(0xFFFF0000)),
          tooltip: '복사한 URL 보기',
          onPressed: () => YoutubeClipboardWatch.pasteAndPlay(context),
        ),
        Material(
          color: const Color(0xFFFF0000),
          borderRadius: BorderRadius.circular(IsleSize.minTouchTarget / 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(IsleSize.minTouchTarget / 2),
            onTap: () => context.push('/youtube/browser'),
            child: const SizedBox(
              width: IsleSize.minTouchTarget,
              height: IsleSize.minTouchTarget,
              child: Icon(Icons.play_arrow, color: Colors.white, size: 26),
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: '더보기',
          icon: const Icon(Icons.more_vert, color: IsleColors.ocean900),
          onSelected: (v) {
            switch (v) {
              case 'platforms':
                showFeedPlatformPickerSheet(context);
              case 'subscribe':
                showAddFeedSubscriptionSheet(context, ref);
              case 'library':
                context.push('/library/sources');
              case 'link':
                showBlockFromLinkSheet(context);
              case 'keywords':
                showKeywordFilterSheet(context);
              case 'paste_url':
                YoutubeClipboardWatch.pasteAndPlay(context);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'paste_url',
              child: ListTile(
                leading: Icon(Icons.content_paste_go, color: Color(0xFFFF0000)),
                title: Text('복사한 URL 보기'),
                subtitle: Text('YouTube 바로 재생'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (!compact)
              const PopupMenuItem(
                value: 'platforms',
                child: ListTile(
                  leading: Icon(Icons.apps_outlined),
                  title: Text('플랫폼 열기'),
                  subtitle: Text('유튜브 · 브런치 · 블로그'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            PopupMenuItem(
              value: 'subscribe',
              child: ListTile(
                leading: const Icon(Icons.rss_feed),
                title: Text(compact ? '구독 추가' : '구독 추가'),
                subtitle: Text(compact ? 'YouTube 채널' : 'YouTube · 브런치 · RSS'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (!compact) ...[
              const PopupMenuItem(
                value: 'library',
                child: ListTile(
                  leading: Icon(Icons.library_books_outlined),
                  title: Text('내 콘텐츠'),
                  subtitle: Text('가져오기 · 요약'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'link',
                child: ListTile(
                  leading: Icon(Icons.link),
                  title: Text('링크로 숨기기'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'keywords',
                child: ListTile(
                  leading: Icon(Icons.tag),
                  title: Text('숨길 키워드'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
