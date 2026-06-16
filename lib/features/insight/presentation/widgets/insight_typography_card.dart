import 'package:flutter/material.dart';

import '../../../../core/insight/models/insight_card.dart';
import '../../../feed/data/models/feed_item.dart';
import 'insight_editorial_card.dart';

/// 피드·프로필 호환 래퍼 — [InsightEditorialCard]
class InsightTypographyCard extends StatelessWidget {
  const InsightTypographyCard({
    super.key,
    this.card,
    this.feedItem,
    this.onTap,
    this.variant = InsightEditorialVariant.feed,
  }) : assert(card != null || feedItem != null);

  final InsightCard? card;
  final FeedItem? feedItem;
  final VoidCallback? onTap;
  final InsightEditorialVariant variant;

  @override
  Widget build(BuildContext context) {
    return InsightEditorialCard(
      card: card,
      feedItem: feedItem,
      onTap: onTap,
      variant: variant,
    );
  }
}
