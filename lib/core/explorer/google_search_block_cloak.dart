/// Google SERP — 차단 스크립트 주입 전 결과 카드 선가림 (플래시 방지)
class GoogleSearchBlockCloak {
  GoogleSearchBlockCloak._();

  /// [방법 1] CSS pre-cloak — 스윕 전까지 결과 카드를 숨김, 안전 카드만 `isle-sk-revealed`로 표시
  static const install = r'''
(function() {
  if (window.__isleGsCloakInstalled) return;
  window.__isleGsCloakInstalled = true;

  function isGoogleSearch() {
    var h = (location.hostname || '').toLowerCase();
    if (!/(^|\.)google\./.test(h) && !/google\.co\./.test(h)) return false;
    var p = location.pathname || '';
    return p === '/search' || p.indexOf('/search') === 0;
  }

  var CARD_SEL =
    '#search div.g:not(.isle-sk-revealed):not([data-isle-gs-kw="1"]):not([data-isle-gs-url="1"]),' +
    '#search div.MjjYud:not(.isle-sk-revealed):not([data-isle-gs-kw="1"]):not([data-isle-gs-url="1"]),' +
    '#search div.Gx5Zad:not(.isle-sk-revealed):not([data-isle-gs-kw="1"]):not([data-isle-gs-url="1"]),' +
    '#search div.xpdopen:not(.isle-sk-revealed):not([data-isle-gs-kw="1"]):not([data-isle-gs-url="1"]),' +
    '#search div[data-hveid]:not(.isle-sk-revealed):not([data-isle-gs-kw="1"]):not([data-isle-gs-url="1"])';

  function installStyle() {
    if (document.getElementById('isle-gs-cloak-style')) return;
    var el = document.createElement('style');
    el.id = 'isle-gs-cloak-style';
    el.textContent = CARD_SEL +
      '{opacity:0!important;visibility:hidden!important;max-height:0!important;' +
      'overflow:hidden!important;contain:strict!important;pointer-events:none!important;}';
    (document.head || document.documentElement).appendChild(el);
  }

  window.__isleGsMarkRevealed = function(node) {
    if (node && node.classList) node.classList.add('isle-sk-revealed');
  };

  function tryInstall() {
    if (!isGoogleSearch()) return;
    installStyle();
    scheduleFailsafe();
  }

  function failsafeReveal() {
    if (!isGoogleSearch()) return;
    var sel =
      '#search div.g, #search div.MjjYud, #search div.Gx5Zad, #search div.xpdopen, #search div[data-hveid]';
    try {
      document.querySelectorAll(sel).forEach(function(node) {
        if (node.getAttribute('data-isle-gs-kw') === '1') return;
        if (node.getAttribute('data-isle-gs-url') === '1') return;
        if (node.getAttribute('data-isle-embed-yt') === '1') return;
        window.__isleGsMarkRevealed(node);
      });
    } catch (e) {}
  }

  function scheduleFailsafe() {
    if (window.__isleGsFailsafeTimers) {
      window.__isleGsFailsafeTimers.forEach(function(id) { clearTimeout(id); });
    }
    window.__isleGsFailsafeTimers = [600, 1500, 3500].map(function(ms) {
      return setTimeout(failsafeReveal, ms);
    });
  }

  tryInstall();
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', tryInstall, { once: true });
  }
})();
''';
}
