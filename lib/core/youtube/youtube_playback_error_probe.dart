import 'package:webview_flutter/webview_flutter.dart';

/// YouTube WebView — 플레이어 영역의 「try again later」 등만 감지 (전체 body 스캔 오탐 방지)
class YoutubePlaybackErrorProbe {
  YoutubePlaybackErrorProbe._();

  static const jsChannelName = 'IslePlayback';

  static String build() {
    const ch = jsChannelName;
    return '''
(function() {
  if (window.__islePlaybackProbe) return;
  window.__islePlaybackProbe = true;
  // WKWebView inline 설정과 video 속성을 함께 적용해야 iOS가 네이티브 플레이어로 빠지지 않는다.
  function prepareInlineVideos() {
    document.querySelectorAll('video').forEach(function(v) {
      if (!v.hasAttribute('playsinline')) v.setAttribute('playsinline', '');
      if (!v.hasAttribute('webkit-playsinline')) v.setAttribute('webkit-playsinline', '');
    });
  }
  prepareInlineVideos();
  new MutationObserver(prepareInlineVideos).observe(document.documentElement, {
    childList: true, subtree: true
  });
  var patterns = [
    'try again later',
    'playback id',
    'an error occurred',
    'something went wrong',
    '오류가 발생',
    '다시 시도',
    'sign in to confirm',
    'not available on this device'
  ];
  var playerSelectors = [
    'ytd-player-error-message-renderer',
    'ytd-playability-error-supported-renderers',
    '.ytp-error',
    '#player-error',
    'ytd-error-screen-renderer'
  ];
  var lastSent = 0;
  function onWatchPage() {
    var p = (location.pathname || '').toLowerCase();
    return p.indexOf('/watch') >= 0 || p.indexOf('/shorts/') >= 0 || p.indexOf('/embed/') >= 0;
  }
  function playerErrorText() {
    for (var i = 0; i < playerSelectors.length; i++) {
      var el = document.querySelector(playerSelectors[i]);
      if (!el) continue;
      var t = (el.innerText || '').trim();
      if (t.length > 4) return t;
    }
    return '';
  }
  function scan() {
    try {
      if (!onWatchPage()) return;
      var playerText = playerErrorText();
      var text = playerText;
      if (!text) {
        var v = document.querySelector('video');
        if (!v || v.readyState >= 2) return;
        text = ((document.querySelector('#player') && document.querySelector('#player').innerText) || '');
      }
      if (!text) return;
      var lower = text.toLowerCase();
      for (var i = 0; i < patterns.length; i++) {
        if (lower.indexOf(patterns[i]) >= 0) {
          var now = Date.now();
          if (now - lastSent < 12000) return;
          lastSent = now;
          $ch.postMessage(JSON.stringify({
            type: 'playback_error',
            pattern: patterns[i],
            snippet: text.substring(0, 280)
          }));
          return;
        }
      }
    } catch (e) {}
  }
  scan();
  setInterval(scan, 3000);
})();
''';
  }

  static Future<void> inject(WebViewController controller) async {
    await controller.runJavaScript(build());
  }
}
