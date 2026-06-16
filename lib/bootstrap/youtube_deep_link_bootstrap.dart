import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../core/navigation/isle_navigation.dart';
import '../core/navigation/isle_navigator_key.dart';
import '../core/navigation/share_link_router.dart';
import '../core/services/isle_app_log_service.dart';
import '../core/services/isle_user_defaults.dart';
import '../core/youtube/youtube_clipboard_quick_actions.dart';

/// YouTube http(s) · isle://youtube 링크 → 앱 내 WebView (기본 핸들러)
class YoutubeDeepLinkBootstrap extends StatefulWidget {
  const YoutubeDeepLinkBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<YoutubeDeepLinkBootstrap> createState() => _YoutubeDeepLinkBootstrapState();
}

class _YoutubeDeepLinkBootstrapState extends State<YoutubeDeepLinkBootstrap>
    with WidgetsBindingObserver {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _handlingResumeClipboard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handleInitialLink());
      _sub = _appLinks.uriLinkStream.listen(_onUri);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_maybeOfferClipboardYoutube());
    }
  }

  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) await _onUri(uri);
    } catch (e, st) {
      IsleAppLogService.log('initialLink: $e', level: IsleLogLevel.warn, stack: st);
    }
  }

  Future<void> _onUri(Uri uri) async {
    final route = ShareLinkRouter.routeFromIncomingUri(uri);
    if (route == null) return;
    final isYoutube = uri.host.toLowerCase().contains('youtube') ||
        uri.host.toLowerCase().contains('youtu.be') ||
        (uri.scheme == 'isle' && uri.host.toLowerCase() == 'youtube');
    if (isYoutube && !IsleUserDefaults.openYoutubeLinksInIsle) return;

    IsleAppLogService.log('Deep link → $route (${uri.toString().length > 80 ? '${uri.toString().substring(0, 80)}…' : uri})');

    for (var i = 0; i < 24; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final ctx = isleNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        if (!IsleNavigation.push(route, from: ctx)) {
          IsleAppLogService.log('Deep link push failed: $route', level: IsleLogLevel.warn);
        }
        return;
      }
    }
  }

  /// Chrome·유튜브 앱에서 링크 복사 후 Isle 복귀 → 열기 · 채널 숨기기 · 영상 숨기기
  Future<void> _maybeOfferClipboardYoutube() async {
    if (_handlingResumeClipboard) return;
    _handlingResumeClipboard = true;
    try {
      final ctx = isleNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      await YoutubeClipboardQuickActions.maybeOffer(ctx);
    } finally {
      _handlingResumeClipboard = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
