import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/share_link_router.dart';
import 'youtube_clipboard_watch.dart';

/// YouTube URL → Isle 인앱 유튜브 브라우저로 보냄 (Safari·Viewer 우회)
class YoutubeUrlRedirect {
  YoutubeUrlRedirect._();

  static final _ytHost = RegExp(r'(youtube\.com|youtu\.be)', caseSensitive: false);

  static bool isYoutubeUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    var t = raw.trim();
    if (!t.startsWith('http')) t = 'https://$t';
    final host = Uri.tryParse(t)?.host.toLowerCase() ?? '';
    return _ytHost.hasMatch(host);
  }

  static String? inAppRoute(String raw) {
    final normalized = YoutubeClipboardWatch.normalizeUrl(raw);
    if (normalized == null) return null;
    return ShareLinkRouter.inAppRouteForUrl(normalized);
  }

  /// true면 YouTube로 리다이렉트됨 (호출 측에서 Safari 열기 중단)
  static bool openInIsle(BuildContext context, String raw) {
    final route = inAppRoute(raw);
    if (route == null) return false;
    context.push(route);
    return true;
  }
}
