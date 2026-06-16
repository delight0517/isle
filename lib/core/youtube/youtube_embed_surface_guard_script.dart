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
    if (el.tagName==='IFRAME') el.removeAttribute('src');
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
    document.querySelectorAll('iframe[src*="youtube"], iframe[src*="googlevideo"], embed[src*="youtube"]').forEach(function(el){
      var card = resultCard(el) || el.parentElement;
      var meta = card ? extractMetaFromCard(card) : metaFromUrl(el.src||'');
      var blocked = matchesBlock(meta);
      if (blocked || cfg.playbackBlocked || cfg.hideInlinePreview){
        stopMedia(el, meta, blocked);
        return;
      }
    });
    document.querySelectorAll('video').forEach(function(v){
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
    var a = e.target && e.target.closest ? e.target.closest('a[href*="youtube.com"], a[href*="youtu.be"]') : null;
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
  function pauseGuard(){
    if (window.__isleEmbedYtObserver) window.__isleEmbedYtObserver.disconnect();
    if (window.__isleEmbedYtTimer) clearInterval(window.__isleEmbedYtTimer);
    if (window.__isleEmbedYtClick) document.removeEventListener('click', window.__isleEmbedYtClick, true);
  }
  function resumeGuard(){
    apply();
    if (window.__isleEmbedYtObserver) window.__isleEmbedYtObserver.disconnect();
    window.__isleEmbedYtObserver = new MutationObserver(function(){ apply(); });
    var root = document.body || document.documentElement;
    if (root) window.__isleEmbedYtObserver.observe(root, {childList:true, subtree:true});
    if (window.__isleEmbedYtTimer) clearInterval(window.__isleEmbedYtTimer);
    window.__isleEmbedYtTimer = setInterval(apply, 1500);
    if (!window.__isleEmbedYtClick){
      window.__isleEmbedYtClick = onClick;
      document.addEventListener('click', window.__isleEmbedYtClick, true);
    }
  }
  window.__islePauseBlocks = pauseGuard;
  window.__isleResumeBlocks = resumeGuard;
  resumeGuard();
})();
''';
  }
}
