import 'dart:convert';

import 'google_search_block_cloak.dart';

/// Google 검색·홈 Discover·뉴스 — 차단 URL 카드 숨김 (Safari WebView)
class GoogleSurfaceUrlBlockScript {
  GoogleSurfaceUrlBlockScript._();

  static String build(
    List<String> blockedUrls, {
    List<String> blockedDomains = const [],
  }) {
    final urls = blockedUrls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final domains = blockedDomains
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (urls.isEmpty && domains.isEmpty) return '';
    final json = jsonEncode(urls);
    final domainsJson = jsonEncode(domains);
    return '''
(function() {
  ${GoogleSearchBlockCloak.install}

  const blockedUrls = $json;
  const blockedDomains = $domainsJson;
  if (!blockedUrls.length && !blockedDomains.length) return;

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

  function domainBlocked(href) {
    if (!blockedDomains.length) return false;
    var h = '';
    try {
      h = (new URL(href, location.href).hostname || '').toLowerCase().replace(/^www\\./, '');
    } catch (e) { return false; }
    if (!h) return false;
    for (var i = 0; i < blockedDomains.length; i++) {
      var d = blockedDomains[i];
      if (h === d || h.endsWith('.' + d)) return true;
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

  function isSafeToCollapse(card) {
    // Google이 결과 여러 개를 하나의 넓은 컨테이너(data-hveid/data-ved 등)로
    // 감싸는 경우가 있어, 그 컨테이너를 통째로 접으면 상관없는 다른 결과까지
    // 같이 사라져 "검색 결과가 아예 안 뜬다"는 문제가 생길 수 있다.
    // 카드 하나에 결과 제목(h3)이 2개 이상이면 여러 결과를 감싸는 넓은
    // 컨테이너로 보고 접지 않는다(도메인 매칭은 넓게, 접기는 좁게).
    if (!card || !card.querySelectorAll) return true;
    return card.querySelectorAll('h3').length <= 1;
  }

  function sweep() {
    if (!isGoogleSurface()) return;
    document.querySelectorAll('a[href]').forEach(function(a) {
      var href = a.href || a.getAttribute('href') || '';
      var card = resultCard(a) || a.closest('div, article, section');
      if (!card) return;
      if ((urlBlocked(href) || domainBlocked(href)) && isSafeToCollapse(card)) {
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
  var scheduleTimer = null;
  function schedule() {
    if (scheduleTimer) return;
    scheduleTimer = setTimeout(function() {
      scheduleTimer = null;
      if (rafPending) return;
      rafPending = true;
      requestAnimationFrame(function() {
        rafPending = false;
        apply();
      });
    }, 180);
  }

  apply();
  [120, 450, 1200, 2800].forEach(function(ms) {
    setTimeout(apply, ms);
  });

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
