import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/youtube/youtube_podcast_audio_script.dart';
import '../../core/youtube/youtube_podcast_listen_store.dart';
import '../../core/youtube/youtube_podcast_session.dart';
import '../../core/youtube/youtube_webview_energy.dart';
import 'youtube_podcast_offscreen_webview.dart';

/// 백그라운드 음성 — 1×1 WebView + 한도 tick
class YoutubePodcastSessionHost extends StatefulWidget {
  const YoutubePodcastSessionHost({super.key});

  @override
  State<YoutubePodcastSessionHost> createState() => _YoutubePodcastSessionHostState();
}

class _YoutubePodcastSessionHostState extends State<YoutubePodcastSessionHost> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    YoutubePodcastSession.instance.addListener(_syncTick);
    _syncTick();
  }

  @override
  void dispose() {
    YoutubePodcastSession.instance.removeListener(_syncTick);
    _tick?.cancel();
    super.dispose();
  }

  void _syncTick() {
    final active = YoutubePodcastSession.instance.hasParkedSession;
    if (active && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
      _onTick();
    } else if (!active) {
      _tick?.cancel();
      _tick = null;
    }
  }

  void _onTick() {
    final s = YoutubePodcastSession.instance;
    final c = s.parkedController;
    if (c == null || !s.minimized) return;

    unawaited(YoutubeWebviewEnergy.setPlaybackBlocked(c, false));
    if (YoutubePodcastListenStore.isLimitReached) {
      unawaited(YoutubeWebviewEnergy.setPlaybackBlocked(c, true));
      return;
    }
    if (YoutubePodcastListenStore.shouldCountListenTime && !s.dartPaused) {
      YoutubePodcastListenStore.addSeconds(1);
    }
    unawaited(c.runJavaScript(YoutubePodcastAudioScript.install));
    if (!s.dartPaused) {
      unawaited(c.runJavaScript(YoutubePodcastAudioScript.setPausedJs(false)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: YoutubePodcastSession.instance,
      builder: (_, __) {
        final c = YoutubePodcastSession.instance.parkedController;
        if (!YoutubePodcastSession.instance.minimized || c == null) {
          return const SizedBox.shrink();
        }
        return YoutubePodcastOffscreenWebview(controller: c);
      },
    );
  }
}
