import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/env.dart';
import '../core/navigation/isle_navigation.dart';
import '../core/navigation/isle_navigator_key.dart';
import '../core/navigation/explorer_entry_guard.dart';
import '../core/navigation/share_link_router.dart';
import '../core/services/pending_share_navigation.dart';
import '../core/services/pending_share_url_store.dart';

/// Safari·YouTube 등 공유 → 앱 내 재생·탐색·아카이브
class ShareIntentBootstrap extends StatefulWidget {
  final Widget child;
  const ShareIntentBootstrap({super.key, required this.child});

  @override
  State<ShareIntentBootstrap> createState() => _ShareIntentBootstrapState();
}

class _ShareIntentBootstrapState extends State<ShareIntentBootstrap> {
  StreamSubscription<List<SharedMediaFile>>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initSharing();
      PendingShareNavigation.tryNavigateFromStoredPending();
    });
  }

  Future<void> _initSharing() async {
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      _routeFromShare(initial);
      await ReceiveSharingIntent.instance.reset();
    } catch (_) {}
    try {
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen(_routeFromShare);
    } catch (_) {}
  }

  void _routeFromShare(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final f = files.first;
    String? url;
    if (f.type == SharedMediaType.url || f.type == SharedMediaType.text) {
      url = f.path.trim();
    }
    if (url == null || url.isEmpty || !url.startsWith('http')) return;

    final inApp = ShareLinkRouter.inAppRouteForUrl(url);
    final needsLoginArchive = Env.isSupabaseConfigured &&
        Supabase.instance.client.auth.currentUser == null &&
        inApp != null &&
        inApp.startsWith('/settings/archive');

    if (needsLoginArchive) {
      PendingShareUrlStore.save(url);
      _snackLoggedOut();
      return;
    }

    final deny = ExplorerEntryGuard.denyMessageForShareUrl(url);
    if (deny != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = isleNavigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        ExplorerEntryGuard.showDenial(ctx, deny, url: url);
      });
      return;
    }

    PendingShareUrlStore.clear();
    final route =
        ShareLinkRouter.inAppRouteForUrl(url) ?? ShareLinkRouter.quickSaveRouteForUrl(url);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = isleNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      IsleNavigation.push(route, from: ctx);
    });
  }

  void _snackLoggedOut() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = isleNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('로그인 후 이 링크로 아카이브 화면이 열립니다.')),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
