import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import '../navigation/isle_navigator_key.dart';
import '../navigation/share_link_router.dart';
import 'pending_share_url_store.dart';

/// 공유·보관 URL을 한 번만 앱 내 라우트로 엽니다.
class PendingShareNavigation {
  PendingShareNavigation._();

  static void tryNavigateFromStoredPending() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final ctx = isleNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      final link = PendingShareUrlStore.take();
      if (link == null || !link.startsWith('http')) return;
      final route =
          ShareLinkRouter.inAppRouteForUrl(link) ?? ShareLinkRouter.quickSaveRouteForUrl(link);
      GoRouter.of(ctx).push(route);
    });
  }
}
