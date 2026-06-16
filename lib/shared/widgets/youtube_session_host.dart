import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/library/platform_watch_limit_store.dart';
import '../../core/youtube/youtube_access_guard.dart';
import '../../core/youtube/youtube_session.dart';
import '../../core/youtube/youtube_webview_energy.dart';

/// 최소화된 유튜브 WebView — 1×1 오프스크린 유지 + 한도 tick·잠금 enforce
class YoutubeSessionHost extends StatefulWidget {
  const YoutubeSessionHost({super.key});

  @override
  State<YoutubeSessionHost> createState() => _YoutubeSessionHostState();
}

class _YoutubeSessionHostState extends State<YoutubeSessionHost> {
  Timer? _parkedTick;

  @override
  void initState() {
    super.initState();
    YoutubeSession.instance.addListener(_syncParkedTick);
    _syncParkedTick();
  }

  @override
  void dispose() {
    YoutubeSession.instance.removeListener(_syncParkedTick);
    _parkedTick?.cancel();
    super.dispose();
  }

  void _syncParkedTick() {
    final active = YoutubeSession.instance.hasParkedSession;
    if (active && _parkedTick == null) {
      _parkedTick = Timer.periodic(const Duration(seconds: 1), (_) => _onParkedTick());
      _onParkedTick();
    } else if (!active) {
      _parkedTick?.cancel();
      _parkedTick = null;
    }
  }

  void _onParkedTick() {
    final c = YoutubeSession.instance.parkedController;
    if (c == null || !YoutubeSession.instance.minimized) return;

    if (YoutubeAccessGuard.shouldBlockWebView) {
      unawaited(YoutubeWebviewEnergy.setPlaybackBlocked(c, true));
      return;
    }
    if (YoutubeAccessGuard.shouldCountWatchTime) {
      PlatformWatchLimitStore.addSeconds(PlatformWatchId.youtube, 1);
    }
    if (YoutubeAccessGuard.shouldBlockWebView) {
      unawaited(YoutubeWebviewEnergy.setPlaybackBlocked(c, true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: YoutubeSession.instance,
      builder: (_, __) {
        final c = YoutubeSession.instance.parkedController;
        if (!YoutubeSession.instance.minimized || c == null) {
          return const SizedBox.shrink();
        }
        return Positioned(
          left: -2,
          top: -2,
          width: 1,
          height: 1,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.01,
              child: WebViewWidget(controller: c),
            ),
          ),
        );
      },
    );
  }
}
