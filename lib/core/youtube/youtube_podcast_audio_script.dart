/// 팟캐스트(음성) 모드 — **영상 프레임·프리뷰 완전 차단** · 오디오만 · iOS 백그라운드
class YoutubePodcastAudioScript {
  YoutubePodcastAudioScript._();

  static const install = '''
(function(){
  if (window.__islePodcastInstalled) {
    if (typeof window.__islePodcastEnforce === 'function') window.__islePodcastEnforce();
    return;
  }
  window.__islePodcastInstalled = true;
  window.__islePodcastPaused = false;

  function injectShieldCss(){
    if (document.getElementById('isle-podcast-shield-css')) return;
    var s = document.createElement('style');
    s.id = 'isle-podcast-shield-css';
    s.textContent =
      'video,canvas,#movie_player,.html5-video-player,.html5-video-container,' +
      '.html5-main-video,.ytp-cued-thumbnail-overlay,.ytp-videowall-still,' +
      '.videowall-still,.ytp-preview,.ytp-storyboard-framepreview,' +
      'ytd-player,ytm-player,.player-api,.ytp-player-content,' +
      '.ytp-iv-video-content,.ytp-ce-element,.ytp-ce-covering-overlay,' +
      '.ytp-pause-overlay,.ytp-scroll-min,.html5-endscreen,' +
      'iframe[src*="youtube"],iframe[src*="googlevideo"]{' +
      'visibility:hidden!important;opacity:0!important;pointer-events:none!important;' +
      'max-width:0!important;max-height:0!important;overflow:hidden!important;' +
      'clip:rect(0,0,0,0)!important;position:fixed!important;' +
      'left:-99999px!important;top:-99999px!important;width:1px!important;height:1px!important;' +
      'filter:brightness(0)!important;}';
    (document.head || document.documentElement).appendChild(s);
  }

  function isWatch(){
    return location.href.indexOf('watch?v=') >= 0;
  }

  function sealVideo(v){
    if (!v || v.getAttribute('data-isle-podcast-sealed') === '1') return;
    v.setAttribute('data-isle-podcast-sealed', '1');
    try {
      v.removeAttribute('controls');
      v.playsInline = true;
      v.setAttribute('playsinline', '');
      v.setAttribute('webkit-playsinline', '');
      v.disablePictureInPicture = true;
      v.style.setProperty('position', 'fixed', 'important');
      v.style.setProperty('left', '-99999px', 'important');
      v.style.setProperty('top', '-99999px', 'important');
      v.style.setProperty('width', '1px', 'important');
      v.style.setProperty('height', '1px', 'important');
      v.style.setProperty('opacity', '0', 'important');
      v.style.setProperty('visibility', 'hidden', 'important');
      v.style.setProperty('pointer-events', 'none', 'important');
      v.style.setProperty('clip', 'rect(0,0,0,0)', 'important');
      v.style.setProperty('object-fit', 'none', 'important');
      v.style.setProperty('filter', 'brightness(0)', 'important');
      if (!window.__islePodcastPaused && v.paused) {
        try { v.play(); } catch (e) {}
      }
      if (!v.__islePodcastBound) {
        v.__islePodcastBound = true;
        ['playing','timeupdate','loadeddata','loadedmetadata','progress','resize'].forEach(function(ev){
          v.addEventListener(ev, hideVideo, true);
        });
      }
    } catch (e) {}
  }

  function hideVideo(){
    try {
      injectShieldCss();
      document.documentElement.style.setProperty('overflow', 'hidden', 'important');
      document.body.style.setProperty('overflow', 'hidden', 'important');
      document.body.style.setProperty('background', '#000', 'important');
      document.querySelectorAll('video').forEach(sealVideo);
      var hide = document.querySelectorAll(
        '#player, #player-container, #player-container-inner, #player-wrap, ' +
        '.html5-video-player, ytd-player, ytm-player, .player-api, ' +
        '.ytp-chrome-bottom, .ytp-chrome-top, .ytp-pause-overlay, .ytp-cued-thumbnail-overlay, ' +
        '.ytp-videowall-still, .videowall-still, .ytp-preview, .ytp-storyboard, ' +
        '.html5-endscreen, #masthead, ytm-mobile-topbar-renderer, ' +
        'ytm-pivot-bar-renderer, ytm-feed, ytm-reel-shelf-renderer, ytm-shorts-lockup-view-model, ' +
        'ytd-reel-shelf-renderer, ytd-rich-item-renderer, #related, #comments, ' +
        '.ytp-ce-element, .ytp-iv-video-content, .ytp-scroll-min'
      );
      for (var j = 0; j < hide.length; j++) {
        hide[j].style.setProperty('display', 'none', 'important');
        hide[j].style.setProperty('visibility', 'hidden', 'important');
        hide[j].style.setProperty('max-height', '0', 'important');
        hide[j].style.setProperty('overflow', 'hidden', 'important');
        hide[j].style.setProperty('opacity', '0', 'important');
      }
      document.querySelectorAll('canvas').forEach(function(c){
        c.style.setProperty('display', 'none', 'important');
        c.style.setProperty('visibility', 'hidden', 'important');
      });
    } catch (e) {}
  }

  function saveData(){
    try {
      var v = document.querySelector('video');
      if (v) {
        if (typeof v.getAvailablePlaybackQualities === 'function') {
          var qs = v.getAvailablePlaybackQualities();
          if (qs && qs.length) {
            try { v.setPlaybackQuality(qs[qs.length - 1]); } catch (e) {}
          }
        }
        if (typeof v.playbackRate !== 'undefined') v.playbackRate = 1.0;
      }
      var imgs = document.querySelectorAll('img:not([data-isle-thumb])');
      for (var i = 0; i < imgs.length && i < 120; i++) {
        imgs[i].style.setProperty('display', 'none', 'important');
      }
    } catch (e) {}
  }

  function blockFs(){
    try {
      document.querySelectorAll('video').forEach(function(v){
        if (v.webkitDisplayingFullscreen && v.webkitExitFullscreen) {
          try { v.webkitExitFullscreen(); } catch (e) {}
        }
      });
      if (document.fullscreenElement && document.exitFullscreen) {
        try { document.exitFullscreen(); } catch (e) {}
      }
    } catch (e) {}
  }

  function blockLeaveWatch(){
    var h = location.href;
    if (h.indexOf('/shorts/') >= 0) {
      var sm = h.match(/\\/shorts\\/([\\w-]{11})/);
      if (sm) location.replace('https://m.youtube.com/watch?v=' + sm[1]);
      return;
    }
    if (!isWatch()) {
      var m = h.match(/[?&]v=([\\w-]{11})/);
      if (m) {
        location.replace('https://m.youtube.com/watch?v=' + m[1]);
      } else if (h.indexOf('youtu.be/') >= 0) {
        var ym = h.match(/youtu\\.be\\/([\\w-]{11})/);
        if (ym) location.replace('https://m.youtube.com/watch?v=' + ym[1]);
      }
    }
  }

  function blockAutoplayNext(){
    try {
      document.querySelectorAll('video').forEach(function(v){
        v.onended = function(){
          if (window.__islePodcastPaused) return;
          try { v.pause(); } catch (e) {}
          if (window.IslePodcastEnded) {
            try { IslePodcastEnded.postMessage('ended'); } catch (e) {}
          }
        };
      });
    } catch (e) {}
  }

  function blockVideoUi(){
    document.addEventListener('click', function(e){
      var t = e.target;
      if (!t) return;
      if (t.tagName === 'VIDEO' || (t.closest && t.closest('#movie_player,.html5-video-player,ytd-player'))) {
        e.preventDefault();
        e.stopImmediatePropagation();
        hideVideo();
      }
    }, true);
    document.addEventListener('dblclick', function(e){
      var t = e.target;
      if (t && (t.tagName === 'VIDEO' || (t.closest && t.closest('#movie_player')))) {
        e.preventDefault();
        e.stopImmediatePropagation();
        blockFs();
      }
    }, true);
  }

  window.__islePodcastEnforce = function(){
    blockLeaveWatch();
    hideVideo();
    saveData();
    blockFs();
    blockAutoplayNext();
  };

  window.__islePodcastSetPaused = function(paused){
    window.__islePodcastPaused = !!paused;
    var v = document.querySelector('video');
    if (!v) return;
    try {
      if (paused) v.pause(); else v.play();
    } catch (e) {}
  };

  window.__islePodcastSeek = function(sec){
    var v = document.querySelector('video');
    if (!v || !isFinite(sec)) return;
    try {
      var d = v.duration || 0;
      v.currentTime = Math.max(0, Math.min(sec, d > 0 ? d - 0.25 : sec));
    } catch (e) {}
  };

  window.__islePodcastSkip = function(delta){
    var v = document.querySelector('video');
    if (!v) return;
    try {
      v.currentTime = Math.max(0, (v.currentTime || 0) + delta);
    } catch (e) {}
  };

  window.__islePodcastGetProgress = function(){
    var v = document.querySelector('video');
    if (!v) return JSON.stringify({t:0,d:0,p:false});
    return JSON.stringify({
      t: v.currentTime || 0,
      d: isFinite(v.duration) ? v.duration : 0,
      p: !v.paused
    });
  };

  window.__islePodcastForcePlay = function(){
    var v = document.querySelector('video');
    if (!v) return;
    try { v.muted = false; v.play(); hideVideo(); } catch (e) {}
  };

  var onFs = function(){ blockFs(); hideVideo(); };
  document.addEventListener('webkitbeginfullscreen', onFs, true);
  document.addEventListener('fullscreenchange', onFs, true);
  document.addEventListener('play', function(){ hideVideo(); saveData(); }, true);
  document.addEventListener('playing', function(){ hideVideo(); }, true);
  document.addEventListener('loadeddata', function(){ hideVideo(); }, true);

  blockVideoUi();

  if (window.__islePodcastMo) window.__islePodcastMo.disconnect();
  window.__islePodcastMo = new MutationObserver(function(){
    window.__islePodcastEnforce();
  });
  var root = document.body || document.documentElement;
  if (root) {
    window.__islePodcastMo.observe(root, { childList: true, subtree: true, attributes: true });
  }

  if (window.__islePodcastTimer) clearInterval(window.__islePodcastTimer);
  window.__islePodcastTimer = setInterval(window.__islePodcastEnforce, 200);
  window.__islePodcastEnforce();

  function setu[REDACTED]
    if (window.__isleWaveReady) return;
    var v = document.querySelector('video');
    if (!v) return;
    try {
      var Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) return;
      if (!window.__isleAudioCtx) window.__isleAudioCtx = new Ctx();
      var ctx = window.__isleAudioCtx;
      if (ctx.state === 'suspended') ctx.resume();
      if (!window.__isleMediaSource) {
        window.__isleMediaSource = ctx.createMediaElementSource(v);
        window.__isleWaveAnalyser = ctx.createAnalyser();
        window.__isleWaveAnalyser.fftSize = 256;
        window.__isleWaveAnalyser.smoothingTimeConstant = 0.72;
        window.__isleMediaSource.connect(window.__isleWaveAnalyser);
        window.__isleWaveAnalyser.connect(ctx.destination);
      }
      window.__isleWaveReady = true;
    } catch (e) {}
  }

  function tickWave(){
    setu[REDACTED]
    var a = window.__isleWaveAnalyser;
    if (!a || window.__islePodcastPaused) return;
    var v = document.querySelector('video');
    if (!v || v.paused) return;
    var buf = new Uint8Array(a.frequencyBinCount);
    a.getByteTimeDomainData(buf);
    var bars = 40;
    var out = [];
    for (var i = 0; i < bars; i++) {
      var idx = Math.floor(i * buf.length / bars);
      var amp = Math.abs(buf[idx] - 128) / 128;
      out.push(Math.round(amp * 1000) / 1000);
    }
    if (window.IslePodcastWaveform) {
      try { IslePodcastWaveform.postMessage(JSON.stringify(out)); } catch (e) {}
    }
  }

  if (window.__isleWaveTimer) clearInterval(window.__isleWaveTimer);
  window.__isleWaveTimer = setInterval(tickWave, 72);
})();
''';

  static const teardown = '''
(function(){
  try {
    if (window.__islePodcastTimer) clearInterval(window.__islePodcastTimer);
    window.__islePodcastTimer = null;
    if (window.__isleWaveTimer) clearInterval(window.__isleWaveTimer);
    window.__isleWaveTimer = null;
    window.__isleWaveReady = false;
    window.__isleMediaSource = null;
    window.__isleWaveAnalyser = null;
    if (window.__islePodcastMo) window.__islePodcastMo.disconnect();
    window.__islePodcastMo = null;
    window.__islePodcastInstalled = false;
    var css = document.getElementById('isle-podcast-shield-css');
    if (css) css.remove();
    document.querySelectorAll('video').forEach(function(v){
      try { v.pause(); } catch (e) {}
    });
  } catch (e) {}
})();
''';

  static const progressJs = 'window.__islePodcastGetProgress && window.__islePodcastGetProgress();';

  static String setPausedJs(bool paused) =>
      'window.__islePodcastSetPaused && window.__islePodcastSetPaused($paused);';

  static String seekJs(double seconds) =>
      'window.__islePodcastSeek && window.__islePodcastSeek($seconds);';

  static String skipJs(int deltaSeconds) =>
      'window.__islePodcastSkip && window.__islePodcastSkip($deltaSeconds);';

  static const forcePlayJs = 'window.__islePodcastForcePlay && window.__islePodcastForcePlay();';

  /// watch URL만 허용 (숏폼·홈·이탈 차단)
  static bool isAllowedListenUrl(String url) {
    final lower = url.toLowerCase();
    if (!lower.contains('youtube.com') && !lower.contains('youtu.be')) {
      return false;
    }
    if (lower.contains('/shorts/')) return false;
    if (lower.contains('/feed') ||
        lower.contains('/results') ||
        lower.contains('/channel/') ||
        lower.contains('/@') ||
        lower.contains('/playlist')) {
      return false;
    }
    return lower.contains('watch?v=') ||
        RegExp(r'youtu\.be/[\w-]{11}').hasMatch(lower);
  }

  static String watchUrlForVideoId(String id) =>
      'https://m.youtube.com/watch?v=$id';
}
