import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/insight/knowledge_visual_system.dart';
import '../../../../core/insight/models/insight_card.dart';
import '../../../../core/share/shared_playlist_store.dart';
import '../../../feed/data/models/feed_item.dart';
import '../../../home/presentation/cc_article_view_screen.dart';
import 'insight_keyword_row.dart';
import 'insight_source_strip.dart';

enum InsightEditorialVariant { feed, immersive }

/// 인사이트 노드 피드 — 타이포 히어로 · 미니멀 소스 · 액센트 키워드
class InsightEditorialCard extends StatelessWidget {
  const InsightEditorialCard({
    super.key,
    this.card,
    this.feedItem,
    this.onTap,
    this.variant = InsightEditorialVariant.feed,
    this.tappable = true,
  }) : assert(card != null || feedItem != null);

  final InsightCard? card;
  final FeedItem? feedItem;
  final VoidCallback? onTap;
  final InsightEditorialVariant variant;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final immersive = variant == InsightEditorialVariant.immersive;
    final fg = immersive ? KnowledgeVisual.onInk : KnowledgeVisual.foreground(b);
    final muted = immersive ? const Color(0xFF9CA3AF) : KnowledgeVisual.mutedFg(b);
    final bg = immersive ? KnowledgeVisual.ink : KnowledgeVisual.cardSurface(b);
    final border = immersive ? Colors.transparent : KnowledgeVisual.cardBorder(b);

    final keywords = card?.keywords ?? feedItem?.detectedTopics ?? const <String>[];
    final hero = _heroLine();
    final title = card?.title ?? feedItem?.title ?? '';
    final channel = card?.channelName ?? feedItem?.channelName ?? '';
    final url = card?.url ?? feedItem?.url ?? '';
    final summaryLines = card?.aiSummaryLines ?? const <String>[];

    final horizontal = immersive ? 0.0 : IsleSize.screenPadding;
    final minH = immersive ? 0.0 : 260.0;

    final child = Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: minH),
          margin: EdgeInsets.symmetric(
            horizontal: horizontal,
            vertical: immersive ? 0 : IsleSize.cardGap,
          ),
          padding: EdgeInsets.fromLTRB(
            immersive ? 24 : 20,
            immersive ? 20 : 18,
            immersive ? 24 : 20,
            immersive ? 32 : 20,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(immersive ? 0 : IsleSize.cardRadius),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InsightSourceStrip(channelName: channel),
              SizedBox(height: immersive ? 28 : 20),
              Text(
                hero,
                style: KnowledgeVisual.editorialHeadline(
                  color: fg,
                  fontSize: immersive ? 32 : 28,
                ),
                maxLines: immersive ? 6 : 5,
                overflow: TextOverflow.ellipsis,
              ),
              if (title.isNotEmpty && title != hero) ...[
                const SizedBox(height: 12),
                Text(
                  title,
                  style: KnowledgeVisual.editorialBody(color: muted, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (summaryLines.isNotEmpty && immersive) ...[
                const SizedBox(height: 20),
                ...summaryLines.take(3).map(
                      (l) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          l,
                          style: KnowledgeVisual.editorialBody(
                            color: const Color(0xFFB0B0B0),
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
              ],
              SizedBox(height: immersive ? 24 : 18),
              InsightKeywordRow(keywords: keywords),
            ],
          ),
        );

    if (!tappable) return child;

    return Semantics(
      label: hero,
      button: true,
      child: GestureDetector(
        onTap: onTap ?? () => _open(context, url, title, card),
        child: child,
      ),
    );
  }

  String _heroLine() {
    final one = card?.oneLiner ?? '';
    final reason = feedItem?.recommendReason ?? '';
    final summary = feedItem?.summary ?? '';
    final title = card?.title ?? feedItem?.title ?? '';
    if (one.trim().isNotEmpty) return one.trim();
    if (reason.trim().isNotEmpty) return reason.trim();
    if (summary.trim().isNotEmpty) return summary.trim();
    return title.trim();
  }

  void _open(BuildContext context, String url, String title, InsightCard? c) {
    if (c != null && c.hasArticle) {
      final legacy = SharedPlaylistItem(
        id: c.id,
        url: c.url,
        title: c.title,
        thumbnailUrl: c.thumbnailUrl,
        sourceType: 'youtube',
        addedAt: c.createdAt,
        channelName: c.channelName,
        transcript: c.transcript,
        articleBody: c.articleBody,
      );
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => CcArticleViewScreen(item: legacy)),
      );
      return;
    }
    if (url.isNotEmpty) {
      context.push('/viewer?url=${Uri.encodeComponent(url)}&title=${Uri.encodeComponent(title)}');
    }
  }
}
