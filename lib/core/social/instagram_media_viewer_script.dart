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
    var path = (location.pathname || '').toLowerCase();
    var fullScreenRoute = isDmThread() || /^\\/(reel|reels)\\//.test(path);
    var w = window.innerWidth || 360;
    var h = window.innerHeight || 640;
    var videos = document.querySelectorAll('video');
    for (var i = 0; i < videos.length; i++) {
      var v = videos[i];
      var r = v.getBoundingClientRect();
      if (r.width < 48 || r.height < 48) continue;
      // DM 썸네일·인라인 영상은 제외 — 전체 화면에 가까울 때만
      if (fullScreenRoute && r.bottom > 0 && r.top < h &&
          r.width >= w * 0.72 && r.height >= h * 0.38) return true;
    }
    var dlg = document.querySelector('[role="dialog"] video');
    if (dlg) {
      var dr = dlg.getBoundingClientRect();
      if (dr.bottom > 0 && dr.top < h &&
          dr.width >= w * 0.55 && dr.height >= h * 0.28) return true;
    }
    return false;
  }

  window.__isleIgForceUnmute = function(resumePlayback) {
    document.querySelectorAll('video').forEach(function(v) {
      try {
        // 이미 음소거 해제·재생 중인 영상은 손대지 않는다 — muted/volume/play()를
        // 매번 다시 써주면 일부 HLS 소스에서 내부적으로 재생을 리셋시켜, 클릭·터치
        // 마다(50ms·300ms·80ms) + 뷰어가 열려 있는 동안 700ms마다 계속 겹쳐 호출되며
        // 영상이 0초로 계속 되감겨 재생/정지를 초당 수십~백여 회 반복하는 무한 루프가
        // 됐다(실사용 확인, 2026-07-20: "영상을 멈추거나 하는 현상"). 실제로 바꿔야
        // 할 때만 건드린다.
        if (v.muted || v.defaultMuted || v.hasAttribute('muted')) {
          v.muted = false;
          v.defaultMuted = false;
          v.removeAttribute('muted');
        }
        if (v.volume !== 1) v.volume = 1;
        if (resumePlayback && v.paused) {
          var p = v.play();
          if (p && p.catch) p.catch(function() {});
        }
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
  function scheduleTick() {
    setTimeout(function() {
      if (document.querySelector('video')) tick();
      scheduleTick();
    }, lastOpen ? 700 : 1600);
  }
  scheduleTick();
})();
''';

  static const forceUnmute =
      'if(window.__isleIgForceUnmute)window.__isleIgForceUnmute(true);';
}
