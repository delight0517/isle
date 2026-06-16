import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// iOS 오디오 재생용 — 화면 밖·완전 비표시 (영상 프레임 노출 금지)
class YoutubePodcastOffscreenWebview extends StatelessWidget {
  const YoutubePodcastOffscreenWebview({super.key, required this.controller});

  final WebViewController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: -12000,
      top: -12000,
      width: 320,
      height: 240,
      child: IgnorePointer(
        ignoring: true,
        child: Opacity(
          opacity: 0,
          child: OverflowBox(
            maxWidth: 1,
            maxHeight: 1,
            child: ClipRect(
              clipBehavior: Clip.hardEdge,
              child: WebViewWidget(controller: controller),
            ),
          ),
        ),
      ),
    );
  }
}
