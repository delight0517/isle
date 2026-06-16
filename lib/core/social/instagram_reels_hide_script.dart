/// Instagram WebView — Reels 탭만 숨김 (DM·피드 본문은 유지)
class InstagramReelsHideScript {
  InstagramReelsHideScript._();

  static const String install = '''
(function() {
  if (window.__isleIgReelsHideInstalled) return;
  window.__isleIgReelsHideInstalled = true;

  function hideReelsNavOnly() {
    const path = (location.pathname || '').toLowerCase();
    if (path.startsWith('/direct')) return;

    document.querySelectorAll('a[href]').forEach(function(a) {
      const h = (a.getAttribute('href') || '').toLowerCase();
      if (h === '/reels/' || h.startsWith('/reels/') || h.indexOf('/reels?') >= 0) {
        const nav = a.closest('nav, header, [role="navigation"]') || a;
        if (nav && nav !== document.body) {
          nav.style.setProperty('display', 'none', 'important');
        }
      }
    });
    document.querySelectorAll('[aria-label*="Reels"], [aria-label*="릴"]').forEach(function(el) {
      const nav = el.closest('a, button, nav, header') || el;
      if (path.startsWith('/direct')) return;
      nav.style.setProperty('display', 'none', 'important');
    });
  }

  hideReelsNavOnly();
  setTimeout(hideReelsNavOnly, 800);
  if (!window.__isleIgReelsObserver) {
    window.__isleIgReelsObserver = new MutationObserver(hideReelsNavOnly);
    const root = document.body || document.documentElement;
    if (root) window.__isleIgReelsObserver.observe(root, { childList: true, subtree: true });
  }
})();
''';
}
