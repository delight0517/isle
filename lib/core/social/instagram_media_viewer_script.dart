/// Instagram DM — SPA 릴스·포스트 뷰어 감지 + 영상 음소거 해제
class InstagramMediaViewerScript {
  InstagramMediaViewerScript._();

  static const jsChannelName = 'IsleIgMedia';

  /// 큰 영상 오버레이 열림/닫힘 → Flutter에 postMessage('open'|'closed')
  static const install = '''
(function() {
  if (window.__isleIgMediaProbeInstalled) return;
  window.__isleIgMediaProbeInstalled = true;

  function post(state) {
    try {
      if (window.IsleIgMedia && window.IsleIgMedia.postMessage) {
        window.IsleIgMedia.postMessage(state);
      }
    } catch (e) {}
  }

  function isDmThread() {
    var p = (location.pathname || '').toLowerCase();
    if (!p.startsWith('/direct/')) return false;
    if (p === '/direct/' || p === '/direct/inbox/' || p.endsWith('/inbox/')) return false;
    return true;
  }

  function mediaViewerOpen() {
    var w = window.innerWidth || 360;
    var h = window.innerHeight || 640;
    var videos = document.querySelectorAll('video');
    for (var i = 0; i < videos.length; i++) {
      var v = videos[i];
      var r = v.getBoundingClientRect();
      if (r.width < 48 || r.height < 48) continue;
      // DM 썸네일·인라인 영상은 제외 — 전체 화면에 가까울 때만
      if (r.width >= w * 0.72 && r.height >= h * 0.38) return true;
    }
    var dlg = document.querySelector('[role="dialog"] video, [role="presentation"] video');
    if (dlg) {
      var dr = dlg.getBoundingClientRect();
      if (dr.width >= w * 0.55 && dr.height >= h * 0.28) return true;
    }
    return false;
  }

  window.__isleIgForceUnmute = function() {
    document.querySelectorAll('video').forEach(function(v) {
      try {
        v.muted = false;
        v.defaultMuted = false;
        v.volume = 1;
        v.removeAttribute('muted');
        var p = v.play();
        if (p && p.catch) p.catch(function() {});
      } catch (e) {}
    });
    try {
      if (window.AudioContext || window.webkitAudioContext) {
        var Ctx = window.AudioContext || window.webkitAudioContext;
        if (!window.__isleIgAudioCtx) window.__isleIgAudioCtx = new Ctx();
        if (window.__isleIgAudioCtx.state === 'suspended') {
          window.__isleIgAudioCtx.resume();
        }
      }
    } catch (e) {}
    var center = document.elementFromPoint(
      Math.floor(window.innerWidth / 2),
      Math.floor(window.innerHeight * 0.35)
    );
    if (center) {
      try { center.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true })); } catch (e) {}
    }
  };

  function tryUnmute() {
    if (window.__isleIgForceUnmute) window.__isleIgForceUnmute();
  }

  var lastOpen = false;
  function tick() {
    var open = mediaViewerOpen();
    if (open !== lastOpen) {
      lastOpen = open;
      post(open ? 'open' : 'closed');
    }
    if (open) tryUnmute();
  }

  document.addEventListener('click', function() {
    setTimeout(tryUnmute, 50);
    setTimeout(tryUnmute, 300);
  }, true);

  document.addEventListener('touchstart', function() {
    setTimeout(tryUnmute, 80);
  }, { passive: true, capture: true });

  tick();
  setInterval(function() {
    if (!document.querySelector('video')) return;
    tick();
  }, 900);
})();
''';

  static const forceUnmute = 'if(window.__isleIgForceUnmute)window.__isleIgForceUnmute();';
}
