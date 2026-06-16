/// m.youtube — Isle 크롬에 가리지 않도록 상·하단 여백 (CSS)
class YoutubeViewportScript {
  YoutubeViewportScript._();

  static String applyPadding({required double topPx, required double bottomPx}) => '''
(function() {
  var id = 'isle-yt-viewport-pad';
  var el = document.getElementById(id);
  if (!el) {
    el = document.createElement('style');
    el.id = id;
    document.head.appendChild(el);
  }
  el.textContent = `
    body { padding-top: ${topPx}px !important; padding-bottom: ${bottomPx}px !important; }
    ytm-mobile-topbar-renderer { margin-top: 0 !important; }
    ytm-pivot-bar-renderer { margin-bottom: 0 !important; }
    ytm-searchbox-suggestions, ytm-section-list-renderer { max-width: 100% !important; }
  `;
})();
''';
}
