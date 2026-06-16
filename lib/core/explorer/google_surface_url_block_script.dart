import 'dart:convert';

import 'google_search_block_cloak.dart';

/// Google 검색·홈 Discover·뉴스 — 차단 URL 카드 숨김 (Safari WebView)
class GoogleSurfaceUrlBlockScript {
  GoogleSurfaceUrlBlockScript._();

  static String build(List<String> blockedUrls) {
    final urls = blockedUrls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (urls.isEmpty) return '';
    final json = jsonEncode(urls);
    return '''
(function() {
  ${GoogleSearchBlockCloak.install}

  const blockedUrls = $json;
  if (!blockedUrls.length) return;

  function normUrl(href) {
    if (!href) return '';
    try {
      var u = new URL(href, location.href);
      var host = (u.hostname || '').toLowerCase().replace(/^www\\./, '');
      var path = u.pathname || '/';
      if (path.length > 1 && path.endsWith('/')) path = path.slice(0, -1);
      var qs = u.searchParams;
      ['utm_source','utm_medium','utm_campaign','utm_term','utm_content','fbclid','gclid','si'].forEach(function(k) {
        qs.delete(k);
      });
      var q = qs.toString();
      var out = 'https://' + host + path + (q ? '?' + q : '');
      var m = href.match(/[?&]v=([a-zA-Z0-9_-]{11})/) ||
        href.match(/\\/shorts\\/([a-zA-Z0-9_-]{11})/) ||
        href.match(/youtu\\.be\\/([a-zA-Z0-9_-]{11})/);
      if (m) return 'https://www.youtube.com/watch?v=' + m[1];
      return out;
    } catch (e) { return String(href).toLowerCase(); }
  }

  function urlBlocked(href) {
    var c = normUrl(href);
    if (!c) return false;
    for (var i = 0; i < blockedUrls.length; i++) {
      if (blockedUrls[i] === c) return true;
    }
    return false;
  }

  function isGoogleSurface() {
    var h = (location.hostname || '').toLowerCase();
    if (/news\\.google\\./.test(h)) return true;
    if (!/(^|\\.)google\\./.test(h) && !/google\\.co\\./.test(h)) return false;
    var p = location.pathname || '';
    if (p === '/search' || p.indexOf('/search') === 0) return true;
    if (p === '/' || p === '') return true;
    return false;
  }

  function resultCard(node) {
    if (!node) return null;
    return node.closest(
      'div.g, div.MjjYud, div.Gx5Zad, div.xpdopen, div[data-hveid], div[data-ved], article, div.n0jPhd'
    );
  }

  function reveal(node) {
    if (typeof window.__isleGsMarkRevealed === 'function') {
      window.__isleGsMarkRevealed(node);
    } else if (node && node.classList) {
      node.classList.add('isle-sk-revealed');
    }
  }

  function collapse(node) {
    if (!node || node.getAttribute('data-isle-gs-url') === '1') return;
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('height', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
    node.setAttribute('data-isle-gs-url', '1');
    node.setAttribute('aria-hidden', 'true');
  }

  function sweep() {
    if (!isGoogleSurface()) return;
    document.querySelectorAll('a[href]').forEach(function(a) {
      var href = a.href || a.getAttribute('href') || '';
      var card = resultCard(a) || a.closest('div, article, section');
      if (!card) return;
      if (urlBlocked(href)) {
        collapse(card);
      } else {
        reveal(card);
      }
    });
  }

  function apply() {
    sweep();
  }

  var rafPending = false;
  function schedule() {
    if (rafPending) return;
    rafPending = true;
    requestAnimationFrame(function() {
      rafPending = false;
      apply();
    });
  }

  apply();
  if (window.__isleGsUrlObserver) window.__isleGsUrlObserver.disconnect();
  window.__isleGsUrlObserver = new MutationObserver(function(muts) {
    for (var i = 0; i < muts.length; i++) {
      if (muts[i].addedNodes && muts[i].addedNodes.length) {
        schedule();
        return;
      }
    }
  });
  var root = document.body || document.documentElement;
  if (root) {
    window.__isleGsUrlObserver.observe(root, { childList: true, subtree: true });
  }
})();
''';
  }
}
