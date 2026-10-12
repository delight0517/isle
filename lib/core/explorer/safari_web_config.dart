import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/isle_sheet.dart';
import '../constants/app_typography.dart';
import '../platform/platform_block_intent.dart';
import '../explorer/explorer_site.dart';
import '../guard/isle_content_block_guard.dart';
import '../navigation/explorer_entry_guard.dart';
import '../safety/content_safety_guard.dart';
import '../youtube/youtube_url_redirect.dart';

/// Isle 안 Safari 스타일 웹 브라우저 (일반 URL · WebView)
class SafariWebConfig {
  SafariWebConfig._();

  static const homeUrl = 'https://www.google.com';

  static const mobileSafariUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';

  static const googleSearchBase = 'https://www.google.com/search';

  static String browserRoute({String? url}) {
    var start = (url?.trim().isNotEmpty ?? false) ? url!.trim() : homeUrl;
    if (!start.startsWith('http')) {
      return browserRoute(url: 'https://$start');
    }
    if (ContentSafetyGuard.matchUrl(start) != null) {
      start = homeUrl;
    } else {
      start = ContentSafetyGuard.sanitizeUrl(start);
    }
    return '/explore/browser?site=custom&url=${Uri.encodeComponent(start)}';
  }

  /// 주소창 입력 정규화: URL이면 그대로(SafeSearch 강제), 아니면 구글 검색.
  /// 검색어(공백 포함·점 없음)는 `https://www.google.com/search?q=...&safe=active`.
  static String resolveQueryOrUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return homeUrl;
    if (_looksLikeUrl(t)) {
      final url = t.startsWith('http') ? t : 'https://$t';
      return enforceSafeSearch(url);
    }
    final q = Uri.encodeQueryComponent(t);
    return ContentSafetyGuard.sanitizeUrl('$googleSearchBase?q=$q&safe=active&hl=ko');
  }

  static bool _looksLikeUrl(String t) {
    if (t.contains(' ')) return false;
    if (t.startsWith('http://') || t.startsWith('https://')) return true;
    final firstSeg = t.split('/').first;
    // 점이 있고 끝나지 않으면 도메인으로 간주 (example.com, a.co/x)
    return firstSeg.contains('.') && !firstSeg.endsWith('.') && !firstSeg.startsWith('.');
  }

  /// 구글 검색 URL이면 `safe=active`를 보장. 이미 적용돼 있으면 null(재로드 불필요).
  static String? safeSearchRewrite(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    final isGoogle = host == 'google.com' ||
        host.endsWith('.google.com') ||
        host.contains('google.co');
    final isSearch = uri.path == '/search' || uri.path.startsWith('/search');
    if (!isGoogle || !isSearch) return null;
    if (uri.queryParameters['safe'] == 'active') return null;
    final qp = Map<String, String>.from(uri.queryParameters);
    qp['safe'] = 'active';
    return uri.replace(queryParameters: qp).toString();
  }

  /// 구글 검색 URL이면 SafeSearch를 적용한 URL, 아니면 원본 그대로.
  static String enforceSafeSearch(String url) => safeSearchRewrite(url) ?? url;

  /// `google.com/search?q=...` 에서 검색어 추출
  static String? searchQueryFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (!host.contains('google')) return null;
    if (uri.path != '/search' && !uri.path.startsWith('/search')) return null;
    final q = uri.queryParameters['q']?.trim();
    if (q == null || q.isEmpty) return null;
    return q;
  }

  static bool isGoogleSearchUrl(String url) => searchQueryFromUrl(url) != null;

  static void open(BuildContext context, {String? url}) {
    var raw = (url?.trim().isNotEmpty ?? false) ? url!.trim() : homeUrl;
    final deny = ExplorerEntryGuard.denyMessageForSite(
      ExplorerSite.custom,
      url: raw,
    );
    if (deny != null) {
      ExplorerEntryGuard.showDenial(
        context,
        deny,
        url: raw,
        site: ExplorerSite.custom,
      );
      return;
    }
    if (ContentSafetyGuard.matchUrl(raw) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('안전 모드: 성인 콘텐츠 사이트는 열 수 없어요')),
      );
      raw = homeUrl;
    } else {
      raw = ContentSafetyGuard.sanitizeUrl(raw);
    }
    context.push(browserRoute(url: raw));
  }

  static Future<void> showUrlSheet(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showIsleModalSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(PlatformBlockCopy.urlSheetTitle, style: IsleText.subtitle()),
            const SizedBox(height: 6),
            Text(
              PlatformBlockCopy.urlSheetSubtitle,
              style: IsleText.caption(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://example.com',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(PlatformBlockCopy.urlSheetOpenButton),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Isle 유튜브에서 열기'),
            ),
          ],
        ),
      ),
    );
    if (ok != null && context.mounted) {
      var raw = ctrl.text.trim();
      var target = raw.isEmpty ? homeUrl : resolveQueryOrUrl(raw);
      final deny = IsleContentBlockGuard.denyInAppSafariNavigation(target);
      if (deny != null) {
        ExplorerEntryGuard.showDenial(
          context,
          deny,
          url: target,
          site: ExplorerSite.custom,
        );
        ctrl.dispose();
        return;
      }
      if (ContentSafetyGuard.matchUrl(target) != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('안전 모드: 성인 콘텐츠 사이트는 열 수 없어요')),
          );
        }
        target = homeUrl;
      }
      if (ok == false && YoutubeUrlRedirect.isYoutubeUrl(target)) {
        final route = YoutubeUrlRedirect.inAppRoute(target);
        if (route != null) {
          context.push(route);
        } else {
          open(context, url: target);
        }
      } else {
        open(context, url: target);
      }
    }
    ctrl.dispose();
  }
}
