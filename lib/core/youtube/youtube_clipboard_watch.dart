import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../explorer/explorer_site.dart';
import '../guard/isle_content_block_guard.dart';
import '../navigation/explorer_entry_guard.dart';
import '../navigation/isle_navigation.dart';

/// 클립보드·붙여넣기 URL → 유튜브 WebView 재생
class YoutubeClipboardWatch {
  YoutubeClipboardWatch._();

  static final _ytHost = RegExp(r'(youtube\.com|youtu\.be)', caseSensitive: false);

  /// watch?v= / shorts / youtu.be → 정규 watch URL
  static String? normalizeUrl(String? raw) {
    if (raw == null) return null;
    var t = raw.trim();
    if (t.isEmpty) return null;
    if (!t.startsWith('http')) t = 'https://$t';
    final uri = Uri.tryParse(t);
    if (uri == null) return null;
    if (!_ytHost.hasMatch(uri.host)) return null;

    if (uri.host.contains('youtu.be')) {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (id.length == 11) return 'https://www.youtube.com/watch?v=$id';
    }
    if (uri.path.contains('/shorts/')) {
      final parts = uri.pathSegments;
      final i = parts.indexOf('shorts');
      if (i >= 0 && i + 1 < parts.length) {
        return 'https://www.youtube.com/watch?v=${parts[i + 1]}';
      }
    }
    if (uri.queryParameters.containsKey('v')) {
      return 'https://www.youtube.com/watch?v=${uri.queryParameters['v']}';
    }
    if (t.contains('youtube.com')) return t.split('#').first;
    return null;
  }

  static Future<String?> readClipboardUrl() async {
    final data = await Clipboard.getData('text/plain');
    return normalizeUrl(data?.text);
  }

  static void openInApp(BuildContext context, String url) {
    final deny = ExplorerEntryGuard.denyMessageForShareUrl(url) ??
        IsleContentBlockGuard.denyUrl(url, inAppExplorer: true);
    if (deny != null) {
      if (context.mounted) {
        ExplorerEntryGuard.showDenial(context, deny, url: url, site: ExplorerSite.youtube);
      }
      return;
    }
    final encoded = Uri.encodeComponent(url);
    if (!IsleNavigation.push('/youtube/browser?url=$encoded', from: context)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('유튜브 화면을 열 수 없어요')),
        );
      }
    }
  }

  /// 복사한 URL 보기 — 붙여넣기와 동시에 플레이어
  static Future<void> pasteAndPlay(BuildContext context) async {
    final url = await readClipboardUrl();
    if (!context.mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클립보드에 YouTube 링크가 없어요')),
      );
      return;
    }
    openInApp(context, url);
  }
}
