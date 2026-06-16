import 'dart:convert';

import 'brunch_blocked_author_store.dart';

/// 브런치·블로그 목록에서 작가·키워드 숨김
class BrunchContentBlockScript {
  BrunchContentBlockScript._();

  static String build({
    required List<BrunchBlockedAuthor> authors,
    required List<String> keywords,
  }) {
    final authorHandles = authors.map((e) => e.handle).where((e) => e.isNotEmpty).toList();
    final authorNames = authors.map((e) => e.displayName).where((e) => e.isNotEmpty).toList();
    return '''
(function() {
  const handles = ${jsonEncode(authorHandles)};
  const names = ${jsonEncode(authorNames)};
  const keywords = ${jsonEncode(keywords.map((e) => e.toLowerCase()).where((e) => e.isNotEmpty).toList())};

  function textOf(el) {
    return (el.innerText || el.textContent || '').toLowerCase();
  }

  function shouldHide(el) {
    const t = textOf(el);
    const href = (el.closest('a') && el.closest('a').href) || '';
    const blob = t + ' ' + href.toLowerCase();
    for (let i = 0; i < handles.length; i++) {
      const h = handles[i];
      if (!h) continue;
      if (blob.indexOf('/@' + h) >= 0 || blob.indexOf('@' + h) >= 0) return true;
    }
    for (let j = 0; j < names.length; j++) {
      const n = names[j];
      if (n && blob.indexOf(n.toLowerCase()) >= 0) return true;
    }
    for (let k = 0; k < keywords.length; k++) {
      if (keywords[k] && blob.indexOf(keywords[k]) >= 0) return true;
    }
    return false;
  }

  function hideIn(root) {
    const cards = root.querySelectorAll('a[href*="/@"], article, li, .wrap_article, [class*="Article"], [class*="card"]');
    cards.forEach(function(el) {
      if (el.offsetParent === null && el.getBoundingClientRect().height === 0) return;
      if (shouldHide(el)) {
        el.style.setProperty('display', 'none', 'important');
        el.setAttribute('data-isle-blocked', '1');
      }
    });
  }

  function run() { hideIn(document); }

  if (window.__isleBrunchObserver) window.__isleBrunchObserver.disconnect();
  run();
  window.__isleBrunchObserver = new MutationObserver(function() { run(); });
  window.__isleBrunchObserver.observe(document.documentElement, { childList: true, subtree: true });
})();
''';
  }
}
