/// m.youtube 상단 「Open App」·앱 유도 버튼 숨김 (좋아요 등 액션은 유지)
class YoutubeOpenAppHideScript {
  YoutubeOpenAppHideScript._();

  static const install = r'''
(function() {
  if (window.__isleHideOpenAppInstalled) return;
  window.__isleHideOpenAppInstalled = true;

  var OPEN_RE = /open\s*the\s*app|open\s*app|open\s*youtube|youtube\s*app|get\s*(the\s*)?app|install\s*app|앱에서\s*열|앱\s*열기|유튜브\s*앱|앱으로\s*보/i;

  function hideEl(el) {
    if (!el || el.getAttribute('data-isle-hide-open-app') === '1') return;
    el.setAttribute('data-isle-hide-open-app', '1');
    el.style.setProperty('display', 'none', 'important');
    el.style.setProperty('visibility', 'hidden', 'important');
    el.style.setProperty('pointer-events', 'none', 'important');
    el.style.setProperty('max-height', '0', 'important');
    el.style.setProperty('overflow', 'hidden', 'important');
  }

  function hrefIsAppDeepLink(href) {
    if (!href) return false;
    var h = href.toLowerCase();
    return h.indexOf('vnd.youtube') >= 0 || h.indexOf('youtube://') === 0 ||
      (h.indexOf('apps.apple.com') >= 0 && h.indexOf('youtube') >= 0) ||
      (h.indexOf('play.google.com') >= 0 && h.indexOf('youtube') >= 0);
  }

  function labelLooksOpenApp(el) {
    var text = (el.textContent || '').replace(/\s+/g, ' ').trim();
    var label = (el.getAttribute('aria-label') || '').trim();
    var title = (el.getAttribute('title') || '').trim();
    var combined = (text + ' ' + label + ' ' + title);
    if (OPEN_RE.test(combined)) return true;
    if (text.length > 0 && text.length < 32 && /^open\s*app$/i.test(text)) return true;
    return false;
  }

  function isLikeOrSubscribe(el) {
    var blob = ((el.getAttribute('aria-label') || '') + ' ' + (el.textContent || '')).toLowerCase();
    if (/like|dislike|subscribe|구독|좋아요|싫어요|share|공유|comment|댓글/.test(blob)) return true;
    return false;
  }

  function shouldHide(el) {
    if (!el || el.nodeType !== 1) return false;
    if (isLikeOrSubscribe(el)) return false;
    var tag = (el.tagName || '').toUpperCase();
    if (tag.indexOf('OPEN-APP') >= 0 || tag.indexOf('APP-PROMO') >= 0) return true;
    if (hrefIsAppDeepLink(el.getAttribute('href'))) return true;
    if (labelLooksOpenApp(el)) return true;
    return false;
  }

  function walkHide(root) {
    if (!root || !root.querySelectorAll) return;
    var sel = [
      'ytm-open-app-button',
      'ytm-app-promo',
      'ytm-app-promo-header-renderer',
      'a[href*="vnd.youtube"]',
      'a[href^="youtube://"]'
    ].join(',');
    root.querySelectorAll(sel).forEach(hideEl);
    root.querySelectorAll('button, a, ytm-button-renderer, yt-button-shape, paper-button, c3-material-button').forEach(function(el) {
      if (shouldHide(el)) hideEl(el);
      else if (el.closest && el.closest('ytm-open-app-button, ytm-app-promo')) hideEl(el);
    });
  }

  function injectCss() {
    var id = 'isle-hide-open-app-css';
    if (document.getElementById(id)) return;
    var st = document.createElement('style');
    st.id = id;
    st.textContent = [
      'ytm-open-app-button, ytm-app-promo, ytm-app-promo-header-renderer { display: none !important; visibility: hidden !important; }',
      'a[href*="vnd.youtube"], a[href^="youtube://"] { display: none !important; pointer-events: none !important; }'
    ].join('\n');
    (document.head || document.documentElement).appendChild(st);
  }

  function apply() {
    injectCss();
    walkHide(document);
  }

  var t = null;
  function schedule() {
    if (t) return;
    t = setTimeout(function() { t = null; apply(); }, 120);
  }

  apply();
  schedule();
  setTimeout(apply, 500);
  setTimeout(apply, 1500);

  if (!window.__isleHideOpenAppObserver) {
    window.__isleHideOpenAppObserver = new MutationObserver(schedule);
    var root = document.body || document.documentElement;
    if (root) {
      window.__isleHideOpenAppObserver.observe(root, { childList: true, subtree: true });
    }
  }
})();
''';
}
