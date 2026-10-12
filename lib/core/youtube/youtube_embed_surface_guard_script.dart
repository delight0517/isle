import 'dart:convert';

import 'models/blocked_channel.dart';

/// Safari(custom) 등 비-YouTube URL 페이지 — 임베드·인라인 YouTube 재생에
/// 차단 규칙·한도·시청 시간 heartbeat 적용
class YoutubeEmbedSurfaceGuardScript {
  YoutubeEmbedSurfaceGuardScript._();

  static String build({
    required List<BlockedChannel> channels,
    required List<String> blockedVideoIds,
    required List<String> blockedKeywords,
    required bool playbackBlocked,
    required bool hideInlinePreview,
    List<String> blockedUrls = const [],
  }) {
    final cfgLiteral = jsonEncode({
      'channels': channels
          .map((c) => {'id': c.channelId, 'name': c.channelName})
          .toList(),
      'videoIds': blockedVideoIds,
      'keywords': blockedKeywords,
      'blockedUrls': blockedUrls,
      'playbackBlocked': playbackBlocked,
      'hideInlinePreview': hideInlinePreview,
    });
    return '''
(function(){
  var cfg = $cfgLiteral;
  if (window.__isleEmbedYtGuard && window.__isleEmbedYtCfgSig === JSON.stringify(cfg)) return;
  window.__isleEmbedYtGuard = true;
  window.__isleEmbedYtCfgSig = JSON.stringify(cfg);

  function norm(s){ return String(s||'').toLowerCase().trim(); }
  function isYoutubeHint(s){
    if (!s) return false;
    s = String(s).toLowerCase();
    return s.indexOf('youtube.com')>=0 || s.indexOf('youtu.be')>=0 ||
      s.indexOf('googlevideo.com')>=0 || s.indexOf('ytimg.com')>=0;
  }
  function isGoogleSearch(){
    var h = (location.hostname||'').toLowerCase();
    if (!/(^|\\.)google\\./.test(h) && !/google\\.co\\./.test(h)) return false;
    var p = location.pathname||'';
    return p==='/search' || p.indexOf('/search')===0;
  }
  function resultCard(node){
    if (!node) return null;
    return node.closest('div.g, div.MjjYud, div[data-hveid], div[data-ved], div.xpdopen, div.kno-fv');
  }
  function extractVideoId(href){
    if (!href) return '';
    try {
      var u = new URL(href, location.href);
      var v = u.searchParams.get('v');
      if (v && v.length===11) return v;
      var parts = u.pathname.split('/').filter(Boolean);
      if (parts[0]==='shorts' && parts[1] && parts[1].length===11) return parts[1];
      if (parts[0]==='embed' && parts[1] && parts[1].length===11) return parts[1];
    } catch(e){}
    var m = String(href).match(/[?&]v=([a-zA-Z0-9_-]{11})/);
    if (m) return m[1];
    m = String(href).match(/youtu\\.be\\/([a-zA-Z0-9_-]{11})/);
    if (m) return m[1];
    return '';
  }
  function extractMetaFromCard(card){
    var meta = {videoId:'', channelId:'', channelName:'', videoTitle:'', url:''};
    if (!card) return meta;
    var links = card.querySelectorAll('a[href*="youtube.com"], a[href*="youtu.be"]');
    for (var i=0;i<links.length;i++){
      var href = links[i].href || links[i].getAttribute('href') || '';
      var vid = extractVideoId(href);
      if (vid){ meta.videoId = vid; meta.url = href; break; }
    }
    var text = (card.innerText||'').replace(/\\s+/g,' ').trim();
    meta.videoTitle = text.substring(0, 120);
    var ytIdx = text.toLowerCase().indexOf('youtube');
    if (ytIdx > 0){
      var before = text.substring(0, ytIdx).replace(/[·•|\\-]+\\s*\$/,'').trim();
      var parts = before.split(/[·•|]/);
      if (parts.length) meta.channelName = parts[parts.length-1].trim();
    }
    var cid = card.querySelector('a[href*="/channel/"], a[href*="/@"]');
    if (cid){
      var chref = cid.href || '';
      var m = chref.match(/\\/channel\\/([^/?]+)/);
      if (m) meta.channelId = m[1];
      m = chref.match(/\\/@([^/?]+)/);
      if (m && !meta.channelId) meta.channelId = '@'+m[1];
    }
    return meta;
  }
  function metaFromUrl(href){
    return {videoId: extractVideoId(href), channelId:'', channelName:'', videoTitle:'', url: href};
  }
  function channelMatch(meta){
    var id = norm(meta.channelId);
    var name = norm(meta.channelName);
    for (var i=0;i<cfg.channels.length;i++){
      var c = cfg.channels[i];
      var cid = norm(c.id);
      var cname = norm(c.name);
      if (cid && (id===cid || id==='@'+cid || '@'+id===cid)) return true;
      if (cid && cid.indexOf('@')===0 && id===cid.substring(1)) return true;
      if (name && cname && name===cname) return true;
      if (name && cname && name.indexOf(cname)>=0) return true;
    }
    return false;
  }
  function normUrl(href){
    if (!href) return '';
    try {
      var u = new URL(href, location.href);
      var host = (u.hostname||'').toLowerCase().replace(/^www\\./,'');
      var vid = extractVideoId(href);
      if (vid) return 'https://www.youtube.com/watch?v='+vid;
      var path = u.pathname||'/';
      if (path.length>1 && path.endsWith('/')) path = path.slice(0,-1);
      return 'https://'+host+path+(u.search||'');
    } catch(e){ return norm(href); }
  }
  function urlBlocked(href){
    var c = normUrl(href);
    if (!c || !cfg.blockedUrls) return false;
    for (var i=0;i<cfg.blockedUrls.length;i++){
      if (cfg.blockedUrls[i]===c) return true;
    }
    return false;
  }
  function matchesBlock(meta){
    if (!meta) return false;
    if (meta.url && urlBlocked(meta.url)) return true;
    var vid = meta.videoId || '';
    if (vid.length===11){
      for (var i=0;i<cfg.videoIds.length;i++){
        if (cfg.videoIds[i]===vid) return true;
      }
    }
    var hay = norm((meta.videoTitle||'')+' '+(meta.channelName||'')+' '+(meta.url||''));
    for (var k=0;k<cfg.keywords.length;k++){
      var kw = norm(cfg.keywords[k]);
      if (kw && hay.indexOf(kw)>=0) return true;
    }
    if (channelMatch(meta)) return true;
    if (meta.url) {
      var u = norm(meta.url);
      for (var j=0;j<cfg.keywords.length;j++){
        var k2 = norm(cfg.keywords[j]);
        if (k2 && u.indexOf(encodeURIComponent(k2).toLowerCase())>=0) return true;
      }
    }
    return false;
  }
  function postEmbed(msg){
    try { if (window.IsleEmbedSurface) IsleEmbedSurface.postMessage(JSON.stringify(msg)); } catch(e){}
  }
  function postProbe(meta){
    if (!meta || !meta.videoId) return;
    try {
      if (window.IsleChannel) IsleChannel.postMessage(JSON.stringify({
        videoId: meta.videoId,
        channelId: meta.channelId||'',
        channelName: meta.channelName||'',
        videoTitle: meta.videoTitle||'',
        blockedNav: false
      }));
    } catch(e){}
  }
  // ── iframe을 차단 플레이스홀더로 완전 교체 ──────────────────────────────────
  // removeAttribute('src')만으로는 이미 로드된 iframe 콘텐츠가 계속 재생됨.
  // DOM에서 제거 후 시각적 블록 카드로 대체한다.
  function replaceWithBlockCard(el, meta){
    if (el.getAttribute('data-isle-blocked')==='1') return;
    var w = el.offsetWidth || el.getAttribute('width') || 480;
    var h = el.offsetHeight || el.getAttribute('height') || 270;
    // 이미 로드된 iframe: about:blank로 덮어써서 콘텐츠 즉시 언로드
    try { el.src = 'about:blank'; } catch(e){}
    el.setAttribute('data-isle-blocked','1');
    var card = document.createElement('div');
    card.setAttribute('data-isle-blocked','1');
    card.style.cssText = 'width:'+w+'px;max-width:100%;min-height:'+Math.max(100,h)+'px;'+
      'background:#1a1a2e;display:flex;align-items:center;justify-content:center;'+
      'flex-direction:column;gap:10px;border-radius:10px;'+
      'pointer-events:none;user-select:none;box-sizing:border-box;padding:16px';
    var ic = document.createElement('div');
    ic.textContent = '\\uD83D\\uDEAB';
    ic.style.cssText = 'font-size:28px;line-height:1';
    var lb = document.createElement('div');
    lb.textContent = '\\uCC28\\uB2E8\\uB41C \\uC601\\uC0C1\\uC774\\uC5D0\\uC694';
    lb.style.cssText = 'color:rgba(255,255,255,0.85);font-size:13px;font-weight:600;'+
      'font-family:-apple-system,sans-serif;text-align:center';
    card.appendChild(ic); card.appendChild(lb);
    if (el.parentNode) el.parentNode.replaceChild(card, el);
    postEmbed({type:'blocked', videoId: meta.videoId||'', channelName: meta.channelName||''});
  }
  function collapse(node){
    if (!node || node.getAttribute('data-isle-embed-yt')==='1') return;
    try { node.pause && node.pause(); } catch(e){}
    node.style.setProperty('display','none','important');
    node.style.setProperty('visibility','hidden','important');
    node.style.setProperty('height','0','important');
    node.style.setProperty('pointer-events','none','important');
    node.setAttribute('data-isle-embed-yt','1');
    node.setAttribute('aria-hidden','true');
  }
  function stopMedia(el, meta, blocked){
    try { if (el.pause) el.pause(); } catch(e){}
    if (el.tagName==='IFRAME'){
      if (blocked){
        replaceWithBlockCard(el, meta);
        return;
      }
      // 차단 아닌 숨김(hideInlinePreview): src만 제거 후 collapse
      try { el.src = 'about:blank'; } catch(e){}
      collapse(el.closest('div, section, figure') || el);
      return;
    }
    if (blocked){
      collapse(el.closest('div, section, figure') || el);
      postEmbed({type:'blocked', videoId: meta.videoId||'', channelName: meta.channelName||''});
    } else if (cfg.hideInlinePreview) {
      collapse(el.closest('div, section, figure') || el);
    }
  }
  function cardHasYoutube(card){
    if (!card) return false;
    if (isYoutubeHint(card.innerHTML||'')) return true;
    var links = card.querySelectorAll('a[href]');
    for (var i=0;i<links.length;i++){
      if (isYoutubeHint(links[i].getAttribute('href'))) return true;
    }
    return /\\byoutube\\b/i.test(card.innerText||'');
  }
  function sweep(){
    var playing = null;
    // ── iframe — 차단 대상이면 플레이스홀더로 교체 ───────────────────────────
    // data-src 포함: Naver·Tistory 등 레이지 로드 패턴 대응
    document.querySelectorAll(
      'iframe[src*="youtube"], iframe[src*="googlevideo"], embed[src*="youtube"],'+
      'iframe[data-src*="youtube"], iframe[data-lazy-src*="youtube"]'
    ).forEach(function(el){
      if (el.getAttribute('data-isle-blocked')==='1') return; // 이미 처리됨
      var srcVal = el.src || el.getAttribute('data-src') || el.getAttribute('data-lazy-src') || '';
      var card = resultCard(el) || el.parentElement;
      var meta = card ? extractMetaFromCard(card) : metaFromUrl(srcVal);
      // metaFromUrl으로 videoId를 못 뽑은 경우 src에서 직접 추출
      if (!meta.videoId) meta.videoId = extractVideoId(srcVal);
      var blocked = matchesBlock(meta);
      if (blocked || cfg.playbackBlocked || cfg.hideInlinePreview){
        stopMedia(el, meta, blocked);
      }
    });
    // ── video 요소 ────────────────────────────────────────────────────────────
    document.querySelectorAll('video').forEach(function(v){
      // 이미 차단 처리+보고된 video는 재처리하지 않음 — DOM에 남아있는 한
      // sweep()이 매 tick(0.9~2.2s)마다 다시 훑어 postEmbed({type:'blocked'})를
      // 반복 전송해 스낵바가 안 사라지는 것처럼 보이는 문제(중복 알림) 방지.
      if (v.getAttribute('data-isle-blocked')==='1') return;
      var card = resultCard(v);
      var onGoogle = isGoogleSearch();
      if (onGoogle && !cardHasYoutube(card)) return;
      if (!onGoogle && !isYoutubeHint(v.currentSrc||v.src||'')) {
        var parent = v.closest('[class*="youtube"], [data-youtube], a[href*="youtube"]');
        if (!parent && !cardHasYoutube(card)) return;
      }
      var meta = card ? extractMetaFromCard(card) : {videoId:'', channelName:'', videoTitle:'', url: location.href};
      var blocked = matchesBlock(meta);
      if (blocked || cfg.playbackBlocked){
        if (blocked) v.setAttribute('data-isle-blocked','1');
        stopMedia(v, meta, blocked);
        return;
      }
      if (cfg.hideInlinePreview && onGoogle && cardHasYoutube(card)){
        stopMedia(v, meta, false);
        return;
      }
      if (!v.paused && !v.ended){
        playing = meta;
        postProbe(meta);
      }
    });
    postEmbed({
      type:'heartbeat',
      playing: !!playing,
      videoId: playing ? (playing.videoId||'') : '',
      channelId: playing ? (playing.channelId||'') : '',
      channelName: playing ? (playing.channelName||'') : '',
      videoTitle: playing ? (playing.videoTitle||'') : ''
    });
  }
  function onClick(e){
    // ── 차단된 iframe 영역 클릭 완전 차단 ────────────────────────────────────
    var t = e.target;
    if (t && t.getAttribute && t.getAttribute('data-isle-blocked')==='1'){
      e.preventDefault(); e.stopImmediatePropagation(); return;
    }
    var a = t && t.closest ? t.closest('a[href*="youtube.com"], a[href*="youtu.be"]') : null;
    if (!a) return;
    var href = a.href || a.getAttribute('href') || '';
    if (!isYoutubeHint(href)) return;
    var meta = metaFromUrl(href);
    var card = resultCard(a);
    if (card){
      var cm = extractMetaFromCard(card);
      if (cm.videoId) meta = cm;
      if (!meta.videoTitle) meta.videoTitle = cm.videoTitle;
      if (!meta.channelName) meta.channelName = cm.channelName;
    }
    if (matchesBlock(meta)){
      e.preventDefault();
      e.stopPropagation();
      postEmbed({type:'blockedNav', href: href, videoId: meta.videoId||''});
      try { if (window.IsleChannel) IsleChannel.postMessage(JSON.stringify({blockedNav:true, href:href})); } catch(err){}
    }
  }
  function apply(){ sweep(); }
  // 전체화면 진입은 iOS 네이티브 플레이어 계층으로 올라가는 별도 이벤트라
  // sweep()의 iframe 교체·video collapse 로직을 우회한다 — 특히 이미
  // data-isle-blocked='1'로 한 번 처리된 video 요소는 sweep()이 다시
  // 건드리지 않게 돼 있어서(중복 알림 방지), 전체화면에서 재생이 다시
  // 시작돼도 다음 sweep이 그냥 넘어간다(2026-07-13 실사용 제보 — 외부
  // 페이지에 박힌 유튜브 임베드도 같은 클래스의 버그). 전체화면 진입
  // 이벤트에서 직접 다시 확인해 즉시 pause+탈출한다.
  function onFullscreenEvent(e){
    var video = (e.target && e.target.tagName === 'VIDEO') ? e.target : null;
    if (!video) video = document.fullscreenElement || document.querySelector('video:-webkit-full-screen');
    if (!video) return;
    var card = resultCard(video) || (video.closest ? video.closest('[class*="youtube"], [data-youtube], a[href*="youtube"]') : null);
    var onGoogle = isGoogleSearch();
    if (onGoogle && !cardHasYoutube(card)) return;
    if (!onGoogle && !isYoutubeHint(video.currentSrc||video.src||'') && !cardHasYoutube(card)) return;
    var meta = card ? extractMetaFromCard(card) : {videoId:'', channelName:'', videoTitle:'', url: location.href};
    var blocked = matchesBlock(meta);
    if (blocked || cfg.playbackBlocked){
      try { video.pause(); } catch(e2){}
      try { if (typeof video.webkitExitFullscreen === 'function') video.webkitExitFullscreen(); } catch(e3){}
      try { if (document.fullscreenElement && document.exitFullscreen) document.exitFullscreen(); } catch(e4){}
      if (blocked) video.setAttribute('data-isle-blocked','1');
    }
  }
  function installFullscreenGuard(){
    if (window.__isleEmbedYtFsGuard) return;
    window.__isleEmbedYtFsGuard = true;
    function runImmediateFullscreenCheck(){
      var current = document.fullscreenElement || document.querySelector('video:-webkit-full-screen');
      if (!current) return;
      onFullscreenEvent({target: current});
    }
    document.addEventListener('webkitbeginfullscreen', onFullscreenEvent, true);
    document.addEventListener('fullscreenchange', onFullscreenEvent, true);
    document.addEventListener('webkitfullscreenchange', onFullscreenEvent, true);
    document.addEventListener('enterfullscreen', onFullscreenEvent, true);
    runImmediateFullscreenCheck();
    setTimeout(runImmediateFullscreenCheck, 0);
  }
  function pauseGuard(){
    if (window.__isleEmbedYtObserver) window.__isleEmbedYtObserver.disconnect();
    if (window.__isleEmbedYtAttrObserver) window.__isleEmbedYtAttrObserver.disconnect();
    if (window.__isleEmbedYtTimer) clearInterval(window.__isleEmbedYtTimer);
    if (window.__isleEmbedYtClick) document.removeEventListener('click', window.__isleEmbedYtClick, true);
  }
  function resumeGuard(){
    // 즉시 + 짧은 지연으로 한 번 더 — 레이지 로드 직후 잡기
    apply();
    setTimeout(apply, 150);
    setTimeout(apply, 500);
    // ── MutationObserver 1: childList — 새 iframe 삽입 감지 ─────────────────
    if (window.__isleEmbedYtObserver) window.__isleEmbedYtObserver.disconnect();
    window.__isleEmbedYtObserver = new MutationObserver(function(){ apply(); });
    var root = document.body || document.documentElement;
    if (root) window.__isleEmbedYtObserver.observe(root, {childList:true, subtree:true});
    // ── MutationObserver 2: attributes — src 동적 세팅 감지(레이지 로드) ────
    if (window.__isleEmbedYtAttrObserver) window.__isleEmbedYtAttrObserver.disconnect();
    window.__isleEmbedYtAttrObserver = new MutationObserver(function(mutations){
      for (var i=0;i<mutations.length;i++){
        var m = mutations[i];
        if (m.type==='attributes' && m.target && m.target.tagName==='IFRAME'){
          apply(); break;
        }
      }
    });
    if (root) window.__isleEmbedYtAttrObserver.observe(root, {
      subtree:true, attributes:true, attributeFilter:['src','data-src','data-lazy-src']
    });
    // ── fallback 폴링 — 두 옵저버가 놓친 케이스 보완.
    // 일반 웹페이지에서 300ms 전체 sweep은 비용이 커서, 차단/preview 강제 중에만 더 촘촘히 돈다.
    if (window.__isleEmbedYtTimer) clearInterval(window.__isleEmbedYtTimer);
    window.__isleEmbedYtTimer = setInterval(
      apply,
      (cfg.playbackBlocked || cfg.hideInlinePreview) ? 900 : 2200
    );
    if (!window.__isleEmbedYtClick){
      window.__isleEmbedYtClick = onClick;
      document.addEventListener('click', window.__isleEmbedYtClick, true);
    }
    installFullscreenGuard();
  }
  window.__islePauseBlocks = pauseGuard;
  window.__isleResumeBlocks = resumeGuard;
  resumeGuard();
})();
''';
  }
}
