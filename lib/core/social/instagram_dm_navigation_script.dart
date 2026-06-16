/// Instagram DM — 릴스·포스트 뷰어 닫기 (SPA 오버레이 + URL 이동)
class InstagramDmNavigationScript {
  InstagramDmNavigationScript._();

  /// DM 스레드 URL을 sessionStorage에 저장 (미디어 진입 직전)
  static const saveThreadUrl = '''
(function() {
  if (window.__isleIgNavInstalled) return;
  window.__isleIgNavInstalled = true;

  function isDmThreadPath(path) {
    var p = (path || location.pathname || '').toLowerCase();
    if (!p.startsWith('/direct/')) return false;
    if (p === '/direct/' || p === '/direct/inbox/' || p.endsWith('/inbox/')) return false;
    return true;
  }

  function rememberThread() {
    if (!isDmThreadPath(location.pathname)) return;
    try {
      sessionStorage.setItem('isle_ig_dm_thread_url', location.href);
    } catch (e) {}
  }

  window.__isleIgRememberDmThread = rememberThread;

  function notifyOpen() {
    try {
      if (window.IsleIgMedia && window.IsleIgMedia.postMessage) {
        window.IsleIgMedia.postMessage('open');
      }
    } catch (e) {}
  }

  document.addEventListener('click', function(ev) {
    var a = ev.target && ev.target.closest ? ev.target.closest('a[href]') : null;
    if (!a) return;
    rememberThread();
    var h = (a.getAttribute('href') || '').toLowerCase();
    if (h.indexOf('/reel/') >= 0 || h.indexOf('/p/') >= 0 || h.indexOf('/tv/') >= 0) {
      rememberThread();
      setTimeout(notifyOpen, 80);
      setTimeout(notifyOpen, 400);
    }
  }, true);

  var _lastPath = location.pathname;
  setInterval(function() {
    if (location.pathname !== _lastPath) {
      _lastPath = location.pathname;
      if (isDmThreadPath(location.pathname)) rememberThread();
    }
  }, 400);
})();
''';

  /// 릴스·포스트 뷰어 닫기 — true면 페이지 내에서 처리됨
  static const tryDismissMediaViewer = '''
(function() {
  function clickEl(el) {
    if (!el) return false;
    try {
      if (typeof el.click === 'function') { el.click(); return true; }
      var btn = el.closest ? el.closest('button,[role="button"]') : null;
      if (btn && typeof btn.click === 'function') { btn.click(); return true; }
    } catch (e) {}
    return false;
  }

  function findClose() {
    var labels = ['Close', '닫기', 'Back', '뒤로', 'Go back', '이전'];
    for (var i = 0; i < labels.length; i++) {
      var sel = '[aria-label="' + labels[i] + '"]';
      var nodes = document.querySelectorAll(sel);
      for (var j = 0; j < nodes.length; j++) {
        if (clickEl(nodes[j])) return true;
      }
    }
    var dialogs = document.querySelectorAll('[role="dialog"] button, [role="presentation"] button');
    for (var k = 0; k < dialogs.length; k++) {
      var d = dialogs[k];
      var al = (d.getAttribute('aria-label') || '').toLowerCase();
      if (al.indexOf('close') >= 0 || al.indexOf('back') >= 0 || al.indexOf('닫') >= 0) {
        if (clickEl(d)) return true;
      }
    }
    var headerBtns = document.querySelectorAll('header button, nav button, button');
    for (var h = 0; h < headerBtns.length; h++) {
      var b = headerBtns[h];
      var r = b.getBoundingClientRect();
      if (r.top < 96 && r.left < 96 && r.width >= 24 && r.height >= 24) {
        if (clickEl(b)) return true;
      }
    }
    return false;
  }

  function dismissDmEmbedded() {
    var p = (location.pathname || '').toLowerCase();
    if (!p.startsWith('/direct/')) return false;
    var articles = document.querySelectorAll('article, section[role="presentation"]');
    for (var i = 0; i < articles.length; i++) {
      var art = articles[i];
      if (!art.querySelector('video')) continue;
      var hdrBtn = art.querySelector('header button, header a[role="link"], header svg');
      if (hdrBtn && clickEl(hdrBtn)) return true;
    }
    try { window.scrollTo(0, 0); } catch (e) {}
    return false;
  }

  if (findClose()) return 'dismissed';
  if (dismissDmEmbedded()) return 'dismissed';

  try {
    document.dispatchEvent(new KeyboardEvent('keydown', {
      key: 'Escape', code: 'Escape', keyCode: 27, which: 27, bubbles: true
    }));
    return 'escape';
  } catch (e) {}

  try {
    if (window.history.length > 1) {
      window.history.back();
      return 'history';
    }
  } catch (e) {}

  return 'none';
})();
''';

  static const readSavedThreadUrl = '''
(function() {
  try { return sessionStorage.getItem('isle_ig_dm_thread_url') || ''; } catch (e) { return ''; }
})();
''';

}
