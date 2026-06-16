import 'dart:convert';

import 'google_search_block_cloak.dart';

/// Google 검색 SERP — 키워드 포함 결과 카드 숨김 (Safari WebView)
class GoogleSearchKeywordBlockScript {
  GoogleSearchKeywordBlockScript._();

  static String build(List<String> blockedKeywords) {
    final kws = blockedKeywords
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final json = jsonEncode(kws);
    return '''
(function() {
  ${GoogleSearchBlockCloak.install}

  const blockedKeywords = $json;
  if (!blockedKeywords.length) return;

  function isGoogleSearch() {
    var h = (location.hostname || '').toLowerCase();
    if (!/(^|\\.)google\\./.test(h) && !/google\\.co\\./.test(h)) return false;
    var p = location.pathname || '';
    return p === '/search' || p.indexOf('/search') === 0;
  }

  function norm(s) {
    return (s || '').toLowerCase();
  }

  function hasBlockedKeyword(text) {
    var t = norm(text);
    if (!t) return false;
    for (var i = 0; i < blockedKeywords.length; i++) {
      var kw = blockedKeywords[i];
      if (kw && t.indexOf(kw) >= 0) return true;
    }
    return false;
  }

  function reveal(node) {
    if (typeof window.__isleGsMarkRevealed === 'function') {
      window.__isleGsMarkRevealed(node);
    } else if (node && node.classList) {
      node.classList.add('isle-sk-revealed');
    }
  }

  function collapse(node) {
    if (!node || node.getAttribute('data-isle-gs-kw') === '1') return;
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('height', '0', 'important');
    node.style.setProperty('min-height', '0', 'important');
    node.style.setProperty('max-height', '0', 'important');
    node.style.setProperty('margin', '0', 'important');
    node.style.setProperty('padding', '0', 'important');
    node.style.setProperty('overflow', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
    node.setAttribute('data-isle-gs-kw', '1');
    node.setAttribute('aria-hidden', 'true');
  }

  function collectCards() {
    var selectors = [
      'div.g',
      'div.MjjYud',
      'div.Gx5Zad',
      'div.xpdopen',
      'div[data-hveid]',
      'div#search div[data-ved]'
    ];
    var raw = [];
    selectors.forEach(function(sel) {
      try {
        document.querySelectorAll(sel).forEach(function(n) { raw.push(n); });
      } catch (e) {}
    });
    var uniq = [];
    var seen = new Set();
    raw.forEach(function(node) {
      if (!node || seen.has(node)) return;
      seen.add(node);
      uniq.push(node);
    });
    return uniq.filter(function(card) {
      for (var i = 0; i < uniq.length; i++) {
        var other = uniq[i];
        if (other !== card && other.contains(card)) return false;
      }
      var text = (card.innerText || card.textContent || '').trim();
      return text.length >= 8 && text.length <= 8000;
    });
  }

  function sweep() {
    if (!isGoogleSearch()) return;
    collectCards().forEach(function(card) {
      var text = card.innerText || card.textContent || '';
      if (hasBlockedKeyword(text)) {
        collapse(card);
      } else {
        reveal(card);
      }
    });
  }

  function apply() {
    sweep();
  }

  // [방법 3] 80ms setTimeout 제거 — rAF 1회 배치만 (즉시 1차 스윕)
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
  if (window.__isleGsKwObserver) window.__isleGsKwObserver.disconnect();
  window.__isleGsKwObserver = new MutationObserver(function(muts) {
    for (var i = 0; i < muts.length; i++) {
      if (muts[i].addedNodes && muts[i].addedNodes.length) {
        schedule();
        return;
      }
    }
  });
  var root = document.body || document.documentElement;
  if (root) {
    window.__isleGsKwObserver.observe(root, { childList: true, subtree: true });
  }
})();
''';
  }
}
