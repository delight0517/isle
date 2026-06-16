import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/insight/insight_portfolio_store.dart';
import '../../../core/insight/models/insight_card.dart';

final insightPortfolioProvider = Provider<List<InsightCard>>((ref) {
  ref.watch(insightPortfolioRevisionProvider);
  return InsightPortfolioStore.loadAll();
});

final insightPortfolioRevisionProvider = StateProvider<int>((ref) => 0);

void invalidateInsightPortfolio(WidgetRef ref) {
  ref.read(insightPortfolioRevisionProvider.notifier).state++;
}
