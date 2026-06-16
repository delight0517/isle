/// Instagram DM 집중 — 인박스·대화·상대 프로필·포스트·스토리 (피드·탐색 차단)
class InstagramDmFocusScript {
  InstagramDmFocusScript._();

  /// 키보드 올라올 때 뷰포트가 줄어들도록 meta viewport 재설정
  static const String keyboardFix = '''
(function() {
  var m = document.querySelector('meta[name=viewport]');
  if (!m) { m = document.createElement('meta'); m.name = 'viewport'; document.head.appendChild(m); }
  m.content = 'width=device-width, initial-scale=1, maximum-scale=1, interactive-widget=resizes-content';
})();
''';

  /// DM 대화 스크롤·뷰포트 복원 (릴스→채팅 복귀)
  static const String dmScrollPersistence = '''
(function() {
  if (window.__isleIgDmScrollInstalled) return;
  window.__isleIgDmScrollInstalled = true;

  function isDmThreadPath(path) {
    var p = (path || location.pathname || '').toLowerCase();
    if (!p.startsWith('/direct/')) return false;
    if (p === '/direct/' || p === '/direct/inbox/' || p.endsWith('/inbox/')) return false;
    return true;
  }

  function scrollRoot() {
    var main = document.querySelector('main[role="main"], main, [role="main"]');
    return main || document.scrollingElement || document.documentElement;
  }

  function readScrollY() {
    var root = scrollRoot();
    var y = root.scrollTop || 0;
    if (y < 1) y = window.scrollY || 0;
    return y;
  }

  window.__isleIgSaveDmScroll = function() {
    if (!isDmThreadPath(location.pathname)) return;
    var key = 'isle_ig_dm_scroll:' + location.pathname;
    try { sessionStorage.setItem(key, String(readScrollY())); } catch (e) {}
  };

  window.__isleIgRestoreDmScroll = function() {
    if (!isDmThreadPath(location.pathname)) return;
    var key = 'isle_ig_dm_scroll:' + location.pathname;
    var raw = null;
    try { raw = sessionStorage.getItem(key); } catch (e) {}
    if (raw == null) return;
    var y = parseInt(raw, 10);
    if (!isFinite(y) || y < 0) return;
    function apply() {
      var root = scrollRoot();
      var maxY = Math.max(0, (root.scrollHeight || 0) - (root.clientHeight || 0));
      var safeY = Math.min(y, maxY);
      root.scrollTop = safeY;
      window.scrollTo(0, safeY);
    }
    apply();
    setTimeout(apply, 80);
    setTimeout(apply, 250);
    setTimeout(apply, 700);
  };

  var saveTimer = null;
  function scheduleSave() {
    if (!isDmThreadPath(location.pathname)) return;
    if (saveTimer) clearTimeout(saveTimer);
    saveTimer = setTimeout(function() {
      saveTimer = null;
      window.__isleIgSaveDmScroll();
    }, 120);
  }

  window.addEventListener('scroll', scheduleSave, { passive: true, capture: true });
  document.addEventListener('click', function(ev) {
    var a = ev.target && ev.target.closest ? ev.target.closest('a[href]') : null;
    if (!a) return;
    var h = (a.getAttribute('href') || '').toLowerCase();
    if (h.indexOf('/reel/') >= 0 || h.indexOf('/p/') >= 0 || h.indexOf('/tv/') >= 0) {
      window.__isleIgSaveDmScroll();
    }
  }, true);
})();
''';

  static const restoreScrollAndViewport = '''
(function() {
  var m = document.querySelector('meta[name=viewport]');
  if (!m) { m = document.createElement('meta'); m.name = 'viewport'; document.head.appendChild(m); }
  m.content = 'width=device-width, initial-scale=1, maximum-scale=1, interactive-widget=resizes-content';
  if (window.__isleIgRestoreDmScroll) window.__isleIgRestoreDmScroll();
})();
''';

  static const String script = '''
(function() {
  if (window.__isleIgDmFocusInstalled) return;
  window.__isleIgDmFocusInstalled = true;

  // 키보드 뷰포트 픽스
  var m = document.querySelector('meta[name=viewport]');
  if (!m) { m = document.createElement('meta'); m.name = 'viewport'; document.head.appendChild(m); }
  m.content = 'width=device-width, initial-scale=1, maximum-scale=1, interactive-widget=resizes-content';

  const DM_HOME = 'https://www.instagram.com/direct/inbox/';

  const RESERVED = new Set([
    'direct','explore','reels','accounts','p','reel','tv','stories',
    'legal','privacy','terms','about','developer','directory','landing',
    'email','help','session','challenge','consent','nametag','ar','web','static'
  ]);
  const PROFILE_SUB = new Set(['reels','tagged','channel','guides']);

  function isProfileOrStoriesPath(path) {
    const parts = (path || '').toLowerCase().split('/').filter(Boolean);
    if (parts.length === 0) return false;
    if (parts[0] === 'stories' && parts.length >= 2) {
      return parts[1].length > 0 && !RESERVED.has(parts[1]);
    }
    if (RESERVED.has(parts[0])) return false;
    if (parts.length === 1) return true;
    if (parts.length === 2 && PROFILE_SUB.has(parts[1])) return true;
    return false;
  }

  function allowedPath(path) {
    const p = (path || '').toLowerCase();
    if (p.startsWith('/direct')) return true;
    if (p.startsWith('/accounts')) return true;
    if (p.startsWith('/challenge')) return true;
    if (p.startsWith('/consent')) return true;
    if (p.startsWith('/p/')) return true;
    if (p.startsWith('/reel/')) return true;
    if (p.startsWith('/tv/')) return true;
    if (isProfileOrStoriesPath(p)) return true;
    return false;
  }

  function hideExploreNav() {
    document.querySelectorAll('a[href]').forEach(function(a) {
      const h = (a.getAttribute('href') || '').toLowerCase();
      if (h.startsWith('/explore') || h === '/reels/' || h.startsWith('/reels/')) {
        const host = a.closest('nav, header, li, [role="navigation"]') || a;
        if (host && host !== document.body) host.style.display = 'none';
      }
    });
  }

  function isDmThreadPath(path) {
    var p = (path || location.pathname || '').toLowerCase();
    if (!p.startsWith('/direct/')) return false;
    if (p === '/direct/' || p === '/direct/inbox/' || p.endsWith('/inbox/')) return false;
    return true;
  }

  function guard() {
    const p = location.pathname.toLowerCase();
    if (isDmThreadPath(p)) {
      if (window.__isleIgRestoreDmScroll) window.__isleIgRestoreDmScroll();
      return;
    }
    if (!allowedPath(p)) {
      if (p === '/' || p.startsWith('/reels')) {
        location.replace(DM_HOME);
        return;
      }
    }
    hideExploreNav();
    if (window.__isleIgRestoreDmScroll) window.__isleIgRestoreDmScroll();
  }

  guard();
  setTimeout(guard, 500);
  if (!window.__isleIgDmFocusObserver) {
    window.__isleIgDmFocusObserver = new MutationObserver(function() {
      if (window.__isleIgGuardTimer) return;
      window.__isleIgGuardTimer = setTimeout(function() {
        window.__isleIgGuardTimer = null;
        guard();
      }, 600);
    });
    window.__isleIgDmFocusObserver.observe(document.documentElement, { childList: true, subtree: true });
  }
})();
''';
}
