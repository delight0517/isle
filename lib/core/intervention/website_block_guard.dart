import 'website_block_store.dart';

/// 사용자 「웹사이트 차단」목록 — Isle 인앱 브라우저·외부 열기에도 적용 (Safari CB만이면 우회됨)
class WebsiteBlockGuard {
  WebsiteBlockGuard._();

  static WebsiteBlockHit? matchUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var url = raw.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    return matchHost(uri.host);
  }

  static WebsiteBlockHit? matchHost(String host) {
    final h = host.toLowerCase();
    for (final d in WebsiteBlockStore.loadDomains()) {
      if (_hostMatches(h, d)) {
        String label = d;
        for (final c in WebsiteBlockStore.catalog) {
          if (_hostMatches(h, c.domain)) {
            label = c.label;
            break;
          }
        }
        return WebsiteBlockHit(domain: d, label: label);
      }
    }
    return null;
  }

  static bool _hostMatches(String host, String domain) {
    final d = domain.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final h = host.replaceFirst(RegExp(r'^www\.'), '');
    return h == d || h.endsWith('.$d');
  }
}

class WebsiteBlockHit {
  const WebsiteBlockHit({required this.domain, required this.label});

  final String domain;
  final String label;

  String get snackMessage => '「$label」은(는) 웹사이트 차단 목록에 있어요';
}
