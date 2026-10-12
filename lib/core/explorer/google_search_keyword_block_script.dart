import 'dart:convert';

import 'google_search_block_cloak.dart';

/// Google 검색 SERP — 키워드 포함 결과 카드 숨김 (Safari WebView)
class GoogleSearchKeywordBlockScript {
  GoogleSearchKeywordBlockScript._();

  /// [blockedKeywords]: 사용자 키워드 — 검색어 자체와 겹치면 skip (전체 가림 방지)
  /// [alwaysBlockKeywords]: 내장 성인 키워드 — 검색어 겹쳐도 항상 적용
  static String build(
    List<String> blockedKeywords, {
    String? searchQuery,
    List<String> alwaysBlockKeywords = const [],
  }) {
    final kws = blockedKeywords
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final alwaysKws = alwaysBlockKeywords
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final queryTerms = (searchQuery ?? '')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 2)
        .toList();
    final json = jsonEncode(kws);
    final alwaysJson = jsonEncode(alwaysKws);
    final queryJson = jsonEncode(queryTerms);
    return '''
(function() {
  ${GoogleSearchBlockCloak.install}

  const blockedKeywords = $json;
  const alwaysBlockKeywords = $alwaysJson; // 성인 내장 키워드 — query-skip 면제
  const queryTerms = $queryJson;
  if (!blockedKeywords.length && !alwaysBlockKeywords.length) return;

  function isGoogleSearch() {
    var h = (location.hostname || '').toLowerCase();
    if (!/(^|\\.)google\\./.test(h) && !/google\\.co\\./.test(h)) return false;
    var p = location.pathname || '';
    return p === '/search' || p.indexOf('/search') === 0;
  }

  function norm(s) {
    return (s || '').toLowerCase();
  }

  function keywordSkipped(kw) {
    if (!kw) return true;
    for (var i = 0; i < queryTerms.length; i++) {
      var qt = queryTerms[i];
      if (!qt) continue;
      if (kw === qt || kw.indexOf(qt) >= 0 || qt.indexOf(kw) >= 0) return true;
    }
    return false;
  }

  function hasBlockedKeyword(text) {
    var t = norm(text);
    if (!t) return false;
    // 사용자 키워드: 검색어 겹치면 skip
    for (var i = 0; i < blockedKeywords.length; i++) {
      var kw = blockedKeywords[i];
      if (keywordSkipped(kw)) continue;
      if (kw && t.indexOf(kw) >= 0) return true;
    }
    // 성인 내장 키워드: 검색어 겹쳐도 항상 적용
    for (var j = 0; j < alwaysBlockKeywords.length; j++) {
      var akw = alwaysBlockKeywords[j];
      if (akw && t.indexOf(akw) >= 0) return true;
    }
    return false;
  }

  function cardMatchText(card) {
    var parts = [];
    try {
      card.querySelectorAll('h3, h2, [role="heading"]').forEach(function(el) {
        parts.push(el.innerText || el.textContent || '');
      });
      card.querySelectorAll('a[href]').forEach(function(a) {
        parts.push(a.href || a.getAttribute('href') || '');
        var label = (a.innerText || a.textContent || '').trim();
        if (label.length >= 2 && label.length <= 120) parts.push(label);
      });
    } catch (e) {}
    var joined = parts.join(' ').trim();
    if (joined.length >= 4) return joined;
    return (card.innerText || card.textContent || '').substring(0, 400);
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

  // ── Google 이미지 검색 결과 필터 ──────────────────────────────────────────
  // 이미지 탭(tbm=isch)과 검색 페이지의 이미지 패널 모두 대응.
  // 이미지 셀의 alt·aria-label·data-query 텍스트를 검사해 키워드 일치 시 숨김.
  function isImageSearch() {
    return location.search.indexOf('tbm=isch') >= 0;
  }

  function imageTextOf(el) {
    var parts = [];
    // alt 텍스트 — 이미지 설명
    el.querySelectorAll('img[alt]').forEach(function(img) {
      var a = img.getAttribute('alt') || '';
      if (a.length > 1) parts.push(a);
    });
    // aria-label — 접근성 레이블
    var label = el.getAttribute('aria-label') || '';
    if (label) parts.push(label);
    el.querySelectorAll('[aria-label]').forEach(function(n) {
      var l = n.getAttribute('aria-label') || '';
      if (l.length > 1) parts.push(l);
    });
    // data-* 속성
    ['data-query', 'data-title', 'data-src'].forEach(function(attr) {
      var v = el.getAttribute(attr) || '';
      if (v.length > 1) parts.push(v);
    });
    // 텍스트 노드 (짧을 때만 — 이미지 설명 캡션)
    var txt = (el.innerText || '').trim();
    if (txt.length > 0 && txt.length < 200) parts.push(txt);
    return parts.join(' ');
  }

  function collapseImageCell(el) {
    if (!el || el.getAttribute('data-isle-img-blocked') === '1') return;
    el.setAttribute('data-isle-img-blocked', '1');
    el.style.setProperty('display', 'none', 'important');
    el.style.setProperty('visibility', 'hidden', 'important');
    el.style.setProperty('width', '0', 'important');
    el.style.setProperty('height', '0', 'important');
    el.style.setProperty('overflow', 'hidden', 'important');
    el.style.setProperty('pointer-events', 'none', 'important');
  }

  // 이미지 패널(Knowledge Panel 내 이미지 가로 스크롤) 전체 숨김
  function hideImagePanels() {
    // g-img, g-scrolling-carousel — 검색 결과 페이지 이미지 패널
    ['g-img', 'g-scrolling-carousel', 'div.U3CXa', 'div.Oc8BXe',
     'div.img-result-group', 'div.rg_bx', 'div.isv-r-grid'
    ].forEach(function(sel) {
      try {
        document.querySelectorAll(sel).forEach(function(el) {
          if (el.getAttribute('data-isle-img-blocked') === '1') return;
          // 해당 패널 내에 차단 키워드가 있으면 통째로 숨김
          var text = imageTextOf(el);
          if (hasBlockedKeyword(text) || blockedKeywords.length > 0) {
            collapseImageCell(el.closest('div.g, div.MjjYud') || el);
          }
        });
      } catch (e) {}
    });
  }

  function sweepImageResults() {
    // 이미지 검색 결과 셀 — Google Images 레이아웃 변형 다수 대응
    var imgSelectors = [
      'div.isv-r',           // 기본 이미지 그리드
      'div.F0uyec',          // 이미지 컨테이너 2023+
      'div.eA0Zlc',          // 이미지 카드
      'div[data-ri]',        // 개별 이미지 아이템
      'div.mVDMnf',          // 이미지 카드 변형
      'div.ivg-i',           // 이미지 그룹
      'div.rg_i',            // 구형 레이아웃
      'div.img-search-item', // 대체 레이아웃
    ];
    imgSelectors.forEach(function(sel) {
      try {
        document.querySelectorAll(sel).forEach(function(el) {
          if (el.getAttribute('data-isle-img-blocked') === '1') return;
          var text = imageTextOf(el);
          if (hasBlockedKeyword(text)) {
            collapseImageCell(el);
          }
        });
      } catch (e) {}
    });
  }

  function sweep() {
    if (!isGoogleSearch()) return;
    if (isImageSearch()) {
      // 이미지 검색: 이미지 셀 필터
      sweepImageResults();
    } else {
      // 일반 검색: 텍스트 결과 카드 + 이미지 패널 숨김
      collectCards().forEach(function(card) {
        var text = cardMatchText(card);
        if (hasBlockedKeyword(text)) {
          collapse(card);
        } else {
          reveal(card);
        }
      });
      hideImagePanels();
    }
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
