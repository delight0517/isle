import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/insight/insight_crafter_service.dart';
import '../../../core/insight/models/insight_card.dart';
import '../providers/insight_portfolio_provider.dart';

/// 링크 + 메모 → (클라우드 Edge 우선) 인사이트 카드 — UI 로딩 상태
final insightCrafterProvider =
    AsyncNotifierProvider<InsightCrafterNotifier, InsightCard?>(InsightCrafterNotifier.new);

class InsightCrafterNotifier extends AsyncNotifier<InsightCard?> {
  @override
  FutureOr<InsightCard?> build() => null;

  /// [preferCloud] true면 로그인·옵트인 시 `insight_extractor` Edge 호출
  Future<InsightCard?> craftInsight(
    String videoUrl,
    String userMemo, {
    bool preferCloud = true,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final card = await InsightCrafterService.craftFromUrl(
        videoUrl,
        roughNote: userMemo,
        preferCloud: preferCloud,
      );
      if (card == null) {
        throw StateError('유효하지 않은 링크이거나 분석에 실패했습니다.');
      }
      return card;
    });

    if (state.hasValue && state.value != null) {
      ref.read(insightPortfolioRevisionProvider.notifier).state++;
    }

    return state.valueOrNull;
  }

  void reset() => state = const AsyncData(null);
}
