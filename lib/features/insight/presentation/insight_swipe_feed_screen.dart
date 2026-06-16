import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/insight/insight_portfolio_store.dart';
import '../../../core/insight/knowledge_visual_system.dart';
import '../../../core/insight/models/insight_card.dart';
import '../../../core/share/shared_playlist_store.dart';
import '../../home/presentation/cc_article_view_screen.dart';
import 'widgets/insight_editorial_card.dart';

/// 세로 스와이프 — 지식 정독 모드 (책장 넘김 느낌)
class InsightSwipeFeedScreen extends ConsumerStatefulWidget {
  const InsightSwipeFeedScreen({super.key});

  @override
  ConsumerState<InsightSwipeFeedScreen> createState() => _InsightSwipeFeedScreenState();
}

class _InsightSwipeFeedScreenState extends ConsumerState<InsightSwipeFeedScreen> {
  late final PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  List<InsightCard> get _cards {
    final pub = InsightPortfolioStore.published();
    if (pub.isNotEmpty) return pub;
    return InsightPortfolioStore.timeline(limit: 30);
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    return Scaffold(
      backgroundColor: KnowledgeVisual.ink,
      appBar: AppBar(
        backgroundColor: KnowledgeVisual.ink,
        foregroundColor: KnowledgeVisual.onInk,
        elevation: 0,
        title: Text(
          '인사이트',
          style: KnowledgeVisual.editorialCaption(color: KnowledgeVisual.onInk),
        ),
      ),
      body: cards.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  '발행된 인사이트가 없어요.\n지식 명함에서 카드를 발행해 주세요.',
                  textAlign: TextAlign.center,
                  style: KnowledgeVisual.editorialBody(color: const Color(0xFF9CA3AF)),
                ),
              ),
            )
          : PageView.builder(
              controller: _pageCtrl,
              scrollDirection: Axis.vertical,
              itemCount: cards.length,
              onPageChanged: (_) => HapticFeedback.selectionClick(),
              itemBuilder: (_, i) => _SwipePage(card: cards[i]),
            ),
    );
  }
}

class _SwipePage extends StatelessWidget {
  const _SwipePage({required this.card});
  final InsightCard card;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: InsightEditorialCard(
            card: card,
            variant: InsightEditorialVariant.immersive,
            tappable: false,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: Row(
            children: [
              if (card.hasArticle)
                TextButton(
                  onPressed: () {
                    final legacy = SharedPlaylistItem(
                      id: card.id,
                      url: card.url,
                      title: card.title,
                      thumbnailUrl: card.thumbnailUrl,
                      sourceType: 'youtube',
                      addedAt: card.createdAt,
                      channelName: card.channelName,
                      articleBody: card.articleBody,
                      transcript: card.transcript,
                    );
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (_) => CcArticleViewScreen(item: legacy)),
                    );
                  },
                  child: Text(
                    '기사로 읽기',
                    style: KnowledgeVisual.editorialCaption(color: KnowledgeVisual.onInk),
                  ),
                ),
              const Spacer(),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: KnowledgeVisual.onInk,
                  side: const BorderSide(color: Color(0xFF404040)),
                ),
                onPressed: () => context.push(
                  '/viewer?url=${Uri.encodeComponent(card.url)}&title=${Uri.encodeComponent(card.title)}',
                ),
                child: const Text('원본 영상'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
