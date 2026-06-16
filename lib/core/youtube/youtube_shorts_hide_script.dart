/// YouTube WebView — Shorts·릴 선반 전체 숨김
class YoutubeShortsHideScript {
  YoutubeShortsHideScript._();

  static const String install = '''
(function() {
  if (window.__isleShortsHideInstalled) return;
  window.__isleShortsHideInstalled = true;

  function collapse(node) {
    if (!node || node.getAttribute('data-isle-shorts-hidden') === '1') return;
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
    node.setAttribute('data-isle-shorts-hidden', '1');
    node.setAttribute('aria-hidden', 'true');
  }

  const SHORT_SELECTORS = [
    'ytm-shorts-lockup-view-model',
    'ytm-shorts-lockup-view-model-v2',
    'ytm-reel-item-renderer',
    'ytm-reel-shelf-renderer',
    'ytd-reel-item-renderer',
    'ytd-reel-shelf-renderer',
    'ytd-shorts',
    'ytd-rich-shelf-renderer[is-shorts]',
    'a[href*="/shorts/"]'
  ].join(', ');

  const SHELF_SELECTORS = 'ytd-reel-shelf-renderer, ytm-reel-shelf-renderer, ytd-rich-shelf-renderer[is-shorts]';

  function hideShorts() {
    document.querySelectorAll(SHORT_SELECTORS).forEach(function(el) {
      const card = el.closest(
        'ytm-rich-item-renderer, ytd-rich-item-renderer, ytm-item-section-renderer, ytd-item-section-renderer, ytm-reel-shelf-renderer, ytd-reel-shelf-renderer'
      ) || el;
      collapse(card);
    });
    document.querySelectorAll(SHELF_SELECTORS).forEach(collapse);
    if (location.pathname.indexOf('/shorts') === 0) {
      location.replace('/?isle_no_shorts=1');
    }
  }

  function schedule() {
    if (window.__isleShortsPending) return;
    window.__isleShortsPending = true;
    requestAnimationFrame(function() {
      window.__isleShortsPending = false;
      hideShorts();
    });
  }

  hideShorts();
  schedule();
  setTimeout(schedule, 500);

  if (!window.__isleShortsObserver) {
    window.__isleShortsObserver = new MutationObserver(schedule);
    const root = document.body || document.documentElement;
    if (root) window.__isleShortsObserver.observe(root, { childList: true, subtree: true });
  }
})();
''';
}
