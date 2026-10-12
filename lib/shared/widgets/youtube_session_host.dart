import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/services/isle_app_log_service.dart';
import '../../core/youtube/youtube_access_guard.dart';
import '../../core/youtube/youtube_parked_block_guard.dart';
import '../../core/youtube/youtube_session.dart';
import '../../core/youtube/youtube_webview_energy.dart';

/// 최소화된 유튜브 WebView — 1×1 오프스크린 유지 + 잠금 enforce.
/// 백그라운드/오프스크린 재생은 시청 한도에 포함하지 않는다.
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
    final session = YoutubeSession.instance;
    final c = session.parkedController;
    if (c == null || !session.minimized) return;

    final blockHit = YoutubeParkedBlockGuard.match(
      url: session.currentUrl,
      probe: session.probed,
    );
    if (blockHit != null) {
      IsleAppLogService.log(
        'YouTube parked block: ${blockHit.kind.name} ${blockHit.label}',
      );
      session.quit();
      return;
    }

    if (YoutubeAccessGuard.shouldBlockWebView) {
      unawaited(YoutubeWebviewEnergy.setPlaybackBlocked(c, true));
      return;
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
