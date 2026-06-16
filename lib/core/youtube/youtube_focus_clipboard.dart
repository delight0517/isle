import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/youtube_focus_video.dart';
import 'youtube_clipboard_watch.dart';
import 'youtube_limit_gate.dart';

/// 몰입 모드 — 클립보드 URL → Read-first
class YoutubeFocusClipboard {
  YoutubeFocusClipboard._();

  static String? videoIdFromUrl(String? raw) {
    final url = YoutubeClipboardWatch.normalizeUrl(raw);
    if (url == null) return null;
    final uri = Uri.parse(url);
    final v = uri.queryParameters['v'];
    if (v != null && v.length == 11) return v;
    return null;
  }

  static Future<void> pasteAndOpenReadFirst(BuildContext context) async {
    final url = await YoutubeClipboardWatch.readClipboardUrl();
    if (!context.mounted) return;
    final id = videoIdFromUrl(url);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클립보드에 YouTube 링크가 없어요')),
      );
      return;
    }
    if (!YoutubeLimitGate.guard(context)) return;
    context.push(
      '/youtube-focus/watch/$id',
      extra: YoutubeFocusVideo(
        videoId: id,
        title: 'YouTube',
        channelName: '',
      ),
    );
  }
}
