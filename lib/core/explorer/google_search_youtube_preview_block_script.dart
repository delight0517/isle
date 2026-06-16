/// Google 검색 SERP — YouTube 인라인 미리보기·임베드 재생 차단
class GoogleSearchYoutubePreviewBlockScript {
  GoogleSearchYoutubePreviewBlockScript._();

  static const install = '''
(function() {
  if (window.__isleGoogleYtPreviewBlock) return;
  window.__isleGoogleYtPreviewBlock = true;

  function isGoogleSearch() {
    var h = (location.hostname || '').toLowerCase();
    if (!/(^|\\.)google\\./.test(h) && !/google\\.co\\./.test(h)) return false;
    var p = location.pathname || '';
    return p === '/search' || p.indexOf('/search') === 0;
  }

  function isYoutubeHint(s) {
    if (!s) return false;
    s = String(s).toLowerCase();
    return s.indexOf('youtube.com') >= 0 ||
      s.indexOf('youtu.be') >= 0 ||
      s.indexOf('googlevideo.com') >= 0 ||
      s.indexOf('ytimg.com') >= 0;
  }

  function resultCard(node) {
    if (!node) return null;
    return node.closest(
      'div.g, div.MjjYud, div[data-hveid], div[data-ved], div.xpdopen, div.kno-fv'
    );
  }

  function collapse(node) {
    if (!node || node.getAttribute('data-isle-gyt-preview') === '1') return;
    try { node.pause && node.pause(); } catch (e) {}
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('height', '0', 'important');
    node.style.setProperty('max-height', '0', 'important');
    node.style.setProperty('margin', '0', 'important');
    node.style.setProperty('padding', '0', 'important');
    node.style.setProperty('overflow', 'hidden', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
    node.setAttribute('data-isle-gyt-preview', '1');
    node.setAttribute('aria-hidden', 'true');
  }

  function blockMediaInCard(card) {
    if (!card) return;
    card.querySelectorAll('video, iframe, embed, object').forEach(function(el) {
      var src = el.src || el.getAttribute('src') || '';
      if (isYoutubeHint(src) || el.tagName === 'VIDEO') {
        if (el.tagName === 'IFRAME') el.removeAttribute('src');
        collapse(el);
      }
    });
    card.querySelectorAll('[style*="background"]').forEach(function(el) {
      var bg = el.getAttribute('style') || '';
      if (isYoutubeHint(bg) && (el.querySelector('video') || el.querySelector('iframe'))) {
        collapse(el);
      }
    });
  }

  function cardHasYoutube(card) {
    if (!card) return false;
    var html = card.innerHTML || '';
    if (isYoutubeHint(html)) return true;
    var links = card.querySelectorAll('a[href]');
    for (var i = 0; i < links.length; i++) {
      if (isYoutubeHint(links[i].getAttribute('href'))) return true;
    }
    return /\\byoutube\\b/i.test(card.innerText || '');
  }

  function sweep() {
    if (!isGoogleSearch()) return;

    document.querySelectorAll('iframe[src], embed[src]').forEach(function(el) {
      if (!isYoutubeHint(el.src || el.getAttribute('src'))) return;
      blockMediaInCard(resultCard(el) || el.parentElement);
      collapse(el);
    });

    document.querySelectorAll('video').forEach(function(v) {
      var card = resultCard(v);
      if (!card || !cardHasYoutube(card)) return;
      try { v.pause(); } catch (e) {}
      v.removeAttribute('src');
      try { v.load(); } catch (e2) {}
      var wrap = v.closest('div, section, figure') || v;
      collapse(wrap);
      blockMediaInCard(card);
    });

    document.querySelectorAll('a[href*="youtube.com/watch"], a[href*="youtu.be/"]').forEach(function(a) {
      var card = resultCard(a);
      if (!card) return;
      blockMediaInCard(card);
      card.querySelectorAll('video, iframe, button[aria-label*="재생"], button[aria-label*="Play"]').forEach(collapse);
    });
  }

  function apply() {
    sweep();
  }

  apply();
  if (window.__isleGoogleYtPreviewObserver) {
    window.__isleGoogleYtPreviewObserver.disconnect();
  }
  window.__isleGoogleYtPreviewObserver = new MutationObserver(function() {
    apply();
  });
  var root = document.body || document.documentElement;
  if (root) {
    window.__isleGoogleYtPreviewObserver.observe(root, { childList: true, subtree: true });
  }
})();
''';
}
