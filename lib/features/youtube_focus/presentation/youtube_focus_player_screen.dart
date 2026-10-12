import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_typography.dart';
import '../../../core/youtube/models/youtube_focus_video.dart';
import '../../../core/youtube/youtube_focus_metadata_service.dart';
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
  bool _booting = true;
  YoutubeFocusVideo? _activeVideo;
  DateTime? _playStarted;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    var video = widget.video;
    if (video.channelName.trim().isEmpty) {
      video = await YoutubeFocusMetadataService.enrich(video);
    }
    final channelId = await YoutubeFocusMetadataService.channelIdFor(video.videoId);
    final deny = YoutubePlaybackAccessGuard.denyPlayback(
      videoId: video.videoId,
      channelId: channelId,
      channelName: video.channelName,
      videoTitle: video.title,
      url: video.watchUrl,
    );
    if (!mounted) return;
    if (deny != null) {
      setState(() {
        _blocked = true;
        _booting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(deny)));
      context.pop();
      return;
    }
    _activeVideo = video;
    _playStarted = DateTime.now();
    final embed =
        'https://www.youtube.com/embed/${video.videoId}?rel=0&modestbranding=1&playsinline=1';
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    if (Platform.isIOS || Platform.isMacOS) {
      controller.setUserAgent(kYoutubeSafariUserAgent);
    }
    await controller.loadRequest(Uri.parse(embed));
    if (!mounted) return;
    _controller = controller;
    if (YoutubeLimitGate.isLocked) {
      await YoutubeWebviewEnergy.setPlaybackBlocked(controller, true);
    }
    if (!mounted) return;
    setState(() => _booting = false);
  }

  @override
  void dispose() {
    final total = (_activeVideo ?? widget.video).durationSeconds;
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
    final video = _activeVideo ?? widget.video;

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
          if (_blocked || _booting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
            );
          }
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
                  video.title,
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
