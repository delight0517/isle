import 'dart:io' show Platform;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_typography.dart';
import '../../../core/youtube/models/youtube_focus_video.dart';
import '../../../core/youtube/youtube_limit_gate.dart';
import '../../../core/youtube/youtube_playback_access_guard.dart';
import '../../../core/youtube/youtube_webview_factory.dart';
import '../../../core/youtube/youtube_webview_energy.dart';

/// 단일 영상만 — 연관 추천·홈 최소화 (embed)
class YoutubeFocusPlayerScreen extends StatefulWidget {
  const YoutubeFocusPlayerScreen({
    super.key,
    required this.video,
    this.onSessionEnd,
  });

  final YoutubeFocusVideo video;
  final void Function(int savedSeconds)? onSessionEnd;

  @override
  State<YoutubeFocusPlayerScreen> createState() => _YoutubeFocusPlayerScreenState();
}

class _YoutubeFocusPlayerScreenState extends State<YoutubeFocusPlayerScreen> {
  WebViewController? _controller;
  bool _blocked = false;
  DateTime? _playStarted;

  @override
  void initState() {
    super.initState();
    final deny = YoutubePlaybackAccessGuard.denyPlayback(
      videoId: widget.video.videoId,
      channelName: widget.video.channelName,
      videoTitle: widget.video.title,
      url: widget.video.watchUrl,
    );
    if (deny != null) {
      _blocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(deny)));
        context.pop();
      });
      return;
    }
    _playStarted = DateTime.now();
    final id = widget.video.videoId;
    final embed =
        'https://www.youtube.com/embed/$id?rel=0&modestbranding=1&playsinline=1';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    final controller = _controller!;
    if (Platform.isIOS || Platform.isMacOS) {
      // §6.8 — 순수 Safari UA 단독. 식별 토큰 추가 시 구글 봇 감지로 「try again later」 유발.
      controller.setUserAgent(kYoutubeSafariUserAgent);
    }
    controller.loadRequest(Uri.parse(embed));
    if (YoutubeLimitGate.isLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(YoutubeWebviewEnergy.setPlaybackBlocked(controller, true));
      });
    }
  }

  @override
  void dispose() {
    final total = widget.video.durationSeconds;
    if (total > 0 && _playStarted != null) {
      final watched = DateTime.now().difference(_playStarted!).inSeconds;
      final saved = (total - watched).clamp(0, total);
      if (saved > 30) {
        widget.onSessionEnd?.call(saved);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: fg,
        title: Text(
          '재생 중',
          style: IsleText.subtitle(color: fg),
        ),
        actions: [
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/youtube-focus/more'),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_blocked) return const SizedBox.shrink();
          final controller = _controller;
          if (controller == null) return const SizedBox.shrink();
          final locked = YoutubeLimitGate.lockedBody(context);
          if (locked != null) return locked;
          return Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: WebViewWidget(controller: controller),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: IsleText.body(color: Colors.white70),
            ),
          ),
        ],
      );
        },
      ),
    );
  }
}
