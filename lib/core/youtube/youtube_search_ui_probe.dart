/// m.youtube 검색·자동완성 UI — Isle 크롬 숨김 신호
class YoutubeSearchUiProbe {
  YoutubeSearchUiProbe._();

  static const jsChannelName = 'IsleYtSearch';

  /// 주기·포커스 감지 → `1` / `0` postMessage
  static const installWatcher = '''
(function() {
  if (window.__isleYtSearchWatch) return;
  window.__isleYtSearchWatch = true;
  function probe() {
    try {
      var url = location.href || '';
      var fromUrl = /[?&]search_query=/.test(url) || /\\/results/.test(url);
      var inp = document.querySelector(
        'input[type=search], input[name=search_query], ytm-searchbox input, #search-input input'
      );
      var focused = inp && document.activeElement === inp;
      var panel = document.querySelector(
        'ytm-searchbox-suggestions, ytm-section-list-renderer[page-subtype="search"], [role="listbox"]'
      );
      var panelOpen = false;
      if (panel) {
        var r = panel.getBoundingClientRect();
        panelOpen = r.height > 48 && r.width > 80;
      }
      var active = fromUrl || focused || panelOpen;
      if (active !== window.__isleYtSearchActive) {
        window.__isleYtSearchActive = active;
        if (window.IsleYtSearch && window.IsleYtSearch.postMessage) {
          window.IsleYtSearch.postMessage(active ? '1' : '0');
        }
      }
    } catch (e) {}
  }
  probe();
  setInterval(probe, 900);
  document.addEventListener('focusin', probe, true);
  document.addEventListener('focusout', function() { setTimeout(probe, 100); }, true);
})();
''';
}
