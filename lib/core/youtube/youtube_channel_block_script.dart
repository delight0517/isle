import 'dart:convert';

import 'models/blocked_channel.dart';

/// Isle WebView · 인앱 Safari YouTube — 검색 preview·피드 타일·채널 홈 차단 (4VPN youtube_sentry parity)
class YoutubeChannelBlockScript {
  YoutubeChannelBlockScript._();

  static String build(
    List<BlockedChannel> blockedChannels, {
    List<String> blockedVideoIds = const [],
    List<String> blockedKeywords = const [],
    List<String> blockedUrls = const [],
    bool lightMode = false,
  }) {
    final ids = blockedChannels
        .map((e) => e.channelId)
        .where((e) => e.isNotEmpty)
        .toList();
    final names = blockedChannels
        .map((e) => e.channelName)
        .where((e) => e.isNotEmpty)
        .toList();
    final vids = blockedVideoIds
        .map((e) => e.trim())
        .where((e) => e.length == 11)
        .toList();
    final kws = blockedKeywords
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    final urls =
        blockedUrls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final idsJson = jsonEncode(ids);
    final namesJson = jsonEncode(names);
    final vidsJson = jsonEncode(vids);
    final kwsJson = jsonEncode(kws);
    final urlsJson = jsonEncode(urls);
    final light = lightMode ? 'true' : 'false';

    return '''
(function() {
  const blockedIds = $idsJson;
  const blockedNames = $namesJson;
  const blockedVideoIds = $vidsJson;
  const blockedKeywords = $kwsJson;
  const blockedUrls = $urlsJson;
  const LIGHT = $light;
  const DEBOUNCE_MS = LIGHT ? 520 : 650;

  function norm(s) { return (s || '').toLowerCase().trim(); }
  function compactKey(s) {
    try { return norm(s).replace(/[^a-z0-9\\uac00-\\ud7a3]/g, ''); } catch (_) { return norm(s).replace(/[^a-z0-9]/g, ''); }
  }

  const block = { ids: new Set(), handles: new Set(), names: new Set() };
  blockedIds.forEach(function(id) {
    const n = norm(id);
    if (!n) return;
    if (n.startsWith('uc') && n.length >= 12) block.ids.add(n);
    else if (n.startsWith('@')) { block.handles.add(n.slice(1)); block.handles.add(n); }
    else { block.handles.add(n); block.handles.add('@' + n); block.names.add(n); }
  });
  blockedNames.forEach(function(name) {
    const n = norm(name);
    if (!n) return;
    block.names.add(n);
    if (n.startsWith('@')) block.handles.add(n.slice(1));
    else block.handles.add(n);
  });
  blockedKeywords.forEach(function(kw) { if (kw) block.names.add(norm(kw)); });

  const CARD_SELECTORS = [
    'ytd-search-video-renderer',
    'ytd-search-pyv-renderer',
    'ytm-media-item-renderer',
    'ytm-compact-video-renderer',
    'ytm-video-with-context-renderer',
    'ytm-compact-channel-renderer',
    'ytm-rich-item-renderer',
    'ytm-rich-grid-media',
    'ytm-media-item',
    'ytm-channel-with-video-renderer',
    'ytm-reel-item-renderer',
    'ytm-reel-shelf-renderer',
    'ytm-shorts-lockup-view-model',
    'ytm-shorts-lockup-view-model-v2',
    'ytd-reel-shelf-renderer',
    'ytd-shorts',
    'ytm-playlist-video-renderer',
    'ytd-compact-video-renderer',
    'ytd-video-renderer',
    'ytd-grid-video-renderer',
    'ytd-rich-item-renderer',
    'ytd-rich-shelf-renderer',
    'ytd-channel-renderer',
    'ytd-playlist-panel-video-renderer',
    'ytd-reel-item-renderer',
    'ytd-compact-radio-renderer',
    'yt-lockup-view-model',
    'yt-lockup-metadata-view-model',
    'compact-media-item',
    'media-item',
    'related-chip-cloud-chip-renderer',
    'ytm-chip-cloud-chip-renderer'
  ].join(', ');

  const LINK_CONTAINERS = [
    'ytd-channel-renderer', 'ytm-compact-channel-renderer', 'ytd-rich-shelf-renderer',
    'ytm-rich-shelf-renderer', 'ytm-shorts-lockup-view-model-v2', 'ytd-item-section-renderer',
    'ytm-item-section-renderer', 'ytd-search-channel-renderer'
  ].join(', ');

  const PREVIEW_SELECTORS = [
    'ytd-video-preview',
    'yt-video-preview',
    'ytd-thumbnail-overlay-loading-preview-renderer',
    'ytm-thumbnail-overlay-loading-preview-renderer',
    '.ytp-inline-preview-ui',
    '.ytp-inline-preview-scrim',
    '[class*="inline-preview"]',
    '[class*="video-preview"]'
  ].join(', ');

  function isWatchOrShortsPage() {
    const href = location.href || '';
    return /[?&]v=[\\w-]{11}/.test(href) || href.indexOf('/shorts/') >= 0;
  }

  function syncBrowsePreviewState() {
    const root = document.documentElement;
    if (!root) return;
    if (isWatchOrShortsPage()) {
      root.removeAttribute('data-isle-yt-browse-preview-block');
    } else {
      root.setAttribute('data-isle-yt-browse-preview-block', '1');
    }
  }

  function hideTile(node) {
    if (!node || node.getAttribute('data-isle-blocked') === '1') return;
    node.style.setProperty('display', 'none', 'important');
    node.style.setProperty('visibility', 'hidden', 'important');
    node.style.setProperty('height', '0', 'important');
    node.style.setProperty('min-height', '0', 'important');
    node.style.setProperty('max-height', '0', 'important');
    node.style.setProperty('margin', '0', 'important');
    node.style.setProperty('padding', '0', 'important');
    node.style.setProperty('overflow', 'hidden', 'important');
    node.style.setProperty('opacity', '0', 'important');
    node.style.setProperty('pointer-events', 'none', 'important');
    node.setAttribute('data-isle-blocked', '1');
    node.setAttribute('aria-hidden', 'true');
  }

  function extractChannelKeys(href) {
    const keys = [];
    if (!href) return keys;
    const h = href.toLowerCase();
    let m = h.match(/\\/channel\\/(uc[\\w-]+)/i);
    if (m) keys.push(norm(m[1]));
    m = h.match(/\\/@([\\w.\\u0080-\\uFFFF-]+)/);
    if (m) { keys.push('@' + norm(m[1])); keys.push(norm(m[1])); }
    m = h.match(/\\/c\\/([\\w.-]+)/);
    if (m) keys.push(norm(m[1]));
    m = h.match(/\\/user\\/([\\w.-]+)/);
    if (m) keys.push(norm(m[1]));
    return keys;
  }

  function hrefBlocked(href) {
    const keys = extractChannelKeys(href);
    for (const k of keys) {
      if (block.ids.has(k)) return true;
      const bare = k.startsWith('@') ? k.slice(1) : k;
      if (block.handles.has(bare) || block.handles.has('@' + bare) || block.handles.has(k)) return true;
    }
    return false;
  }

  function nameBlocked(text) {
    const t = norm(text);
    if (!t) return false;
    for (const n of block.names) {
      if (!n) continue;
      if (t === n || t.includes(n)) return true;
      const ck = compactKey(t), nk = compactKey(n);
      if (ck && nk && (ck.includes(nk) || nk.includes(ck))) return true;
    }
    return false;
  }

  function videoIdFromHref(href) {
    if (!href) return '';
    const h = href.toLowerCase();
    let m = h.match(/[?&]v=([a-z0-9_-]{11})/);
    if (m) return m[1];
    m = h.match(/\\/shorts\\/([a-z0-9_-]{11})/);
    if (m) return m[1];
    m = h.match(/youtu\\.be\\/([a-z0-9_-]{11})/);
    return m ? m[1] : '';
  }

  function normBlockedUrl(href) {
    if (!href) return '';
    try {
      var u = new URL(href, location.href);
      var host = (u.hostname || '').toLowerCase().replace(/^www\\./, '');
      var vid = videoIdFromHref(href);
      if (vid) return 'https://www.youtube.com/watch?v=' + vid;
      var path = u.pathname || '/';
      if (path.length > 1 && path.endsWith('/')) path = path.slice(0, -1);
      var q = u.search;
      return 'https://' + host + path + q;
    } catch (e) { return String(href).toLowerCase(); }
  }

  function urlBlocked(href) {
    var c = normBlockedUrl(href);
    if (!c) return false;
    for (var i = 0; i < blockedUrls.length; i++) {
      if (blockedUrls[i] === c) return true;
    }
    return false;
  }

  function primaryVideoIdFromCard(card) {
    if (!card) return '';
    const links = card.querySelectorAll('a[href*="watch"], a[href*="/shorts/"], a[href*="youtu.be/"]');
    for (let i = 0; i < links.length; i++) {
      const vid = videoIdFromHref(links[i].getAttribute('href') || '');
      if (vid) return vid;
    }
    return '';
  }

  function channelMetaFromCard(card) {
    const meta = { channelId: '', handle: '', channelName: '' };
    if (!card) return meta;
    const links = card.querySelectorAll('a[href*="/@"], a[href*="/channel/"], a[href*="/c/"]');
    for (let i = 0; i < links.length; i++) {
      const href = links[i].getAttribute('href') || '';
      const keys = extractChannelKeys(href);
      for (const k of keys) {
        if (k.startsWith('uc')) meta.channelId = k;
        else if (k.startsWith('@')) meta.handle = k;
        else if (!meta.handle) meta.handle = '@' + k;
      }
    }
    const nameEl = card.querySelector(
      '#channel-name, .ytm-badge-and-byline-renderer, .ytd-channel-name, .compact-media-item-headline, ' +
      '.ytm-media-item-metadata, .media-item-subhead, .media-item-byline, ' +
      '[class*="channel-name"], [class*="byline"], span.ytm-badge-and-byline-item-byline'
    );
    if (nameEl) meta.channelName = norm(nameEl.textContent || '');
    if (!meta.channelName) {
      card.querySelectorAll('a[href*="/@"], a[href*="/channel/"]').forEach(function(a) {
        if (meta.channelName) return;
        var t = norm(a.textContent || a.getAttribute('aria-label') || '');
        if (t && t.length > 1 && t.length < 80) meta.channelName = t;
      });
    }
    return meta;
  }

  function pauseVideosInNode(node) {
    if (!node) return;
    node.querySelectorAll('video').forEach(function(v) {
      try {
        v.pause();
        v.removeAttribute('autoplay');
        v.muted = true;
        if (typeof v.load === 'function') v.load();
      } catch (e) {}
    });
  }

  function suppressPreviewVideo(v) {
    if (!v) return;
    try {
      v.pause();
      v.muted = true;
      v.removeAttribute('autoplay');
      if (!v.paused) v.pause();
      if (Number.isFinite(v.currentTime) && v.currentTime > 0.05) v.currentTime = 0;
    } catch (e) {}
    v.style.setProperty('opacity', '0', 'important');
    v.style.setProperty('visibility', 'hidden', 'important');
    v.style.setProperty('pointer-events', 'none', 'important');
    v.setAttribute('data-isle-preview-blocked', '1');
  }

  function suppressPreviewInNode(node) {
    if (!node) return;
    node.querySelectorAll('video').forEach(suppressPreviewVideo);
    node.querySelectorAll(PREVIEW_SELECTORS).forEach(function(el) {
      el.style.setProperty('display', 'none', 'important');
      el.style.setProperty('visibility', 'hidden', 'important');
      el.style.setProperty('opacity', '0', 'important');
      el.style.setProperty('pointer-events', 'none', 'important');
      el.setAttribute('data-isle-preview-blocked', '1');
    });
  }

  function pauseVideosInBlockedCards(root) {
    const scope = root || document;
    scope.querySelectorAll(CARD_SELECTORS).forEach(function(card) {
      if (!isCardBlocked(card)) return;
      hideTile(card);
      pauseVideosInNode(card);
    });
  }

  function enforceBrowseFeedPlaybackBlock() {
    if (isWatchOrShortsPage()) return;
    document.querySelectorAll('video').forEach(function(v) {
      const card = v.closest(CARD_SELECTORS);
      if (card && isCardBlocked(card)) {
        suppressPreviewVideo(v);
        hideTile(card);
        return;
      }
      // YouTube browse/search/home preview is not an intentional watch action.
      // When block rules are active, stop every preview video on non-watch pages
      // so blocked channels cannot leak through hover/touch previews.
      suppressPreviewVideo(v);
    });
    document.querySelectorAll(PREVIEW_SELECTORS).forEach(function(el) {
      const card = el.closest(CARD_SELECTORS);
      if (card && isCardBlocked(card)) {
        hideTile(card);
      } else {
        suppressPreviewInNode(el);
      }
    });
  }

  function isCardBlocked(card) {
    if (!card) return false;
    const vid = primaryVideoIdFromCard(card);
    if (vid && blockedVideoIds.indexOf(vid) >= 0) return true;
    const meta = channelMetaFromCard(card);
    if (meta.channelId && block.ids.has(meta.channelId)) return true;
    const h = meta.handle.startsWith('@') ? meta.handle.slice(1) : meta.handle;
    if (h && (block.handles.has(h) || block.handles.has('@' + h))) return true;
    const titleEl = card.querySelector('#video-title, .media-item-headline, h3, .compact-media-item-headline');
    const title = titleEl ? norm(titleEl.textContent || '') : '';
    if (nameBlocked(title) || nameBlocked(meta.channelName)) return true;
    const links = card.querySelectorAll('a[href]');
    for (let i = 0; i < links.length; i++) {
      const href = links[i].getAttribute('href') || '';
      if (hrefBlocked(href) || urlBlocked(href)) return true;
    }
    return false;
  }

  function injectChannelCss() {
    const styleId = 'isle-yt-channel-css';
    let el = document.getElementById(styleId);
    if (!el) {
      el = document.createElement('style');
      el.id = styleId;
      (document.head || document.documentElement).appendChild(el);
    }
    const rules = [];
    block.handles.forEach(function(h) {
      const handle = h.startsWith('@') ? h : '@' + h;
      const bare = handle.slice(1);
      if (!bare) return;
      rules.push('a[href*="/@' + bare + '"] { display: none !important; visibility: hidden !important; }');
      rules.push('ytd-rich-item-renderer:has(a[href*="/@' + bare + '"]), ytm-media-item-renderer:has(a[href*="/@' + bare + '"]), ytd-search-video-renderer:has(a[href*="/@' + bare + '"]) { display: none !important; }');
    });
    block.ids.forEach(function(id) {
      rules.push('a[href*="/channel/' + id + '"] { display: none !important; }');
    });
    rules.push('html[data-isle-yt-browse-preview-block="1"] ytd-video-preview, html[data-isle-yt-browse-preview-block="1"] yt-video-preview, html[data-isle-yt-browse-preview-block="1"] ytd-thumbnail-overlay-loading-preview-renderer, html[data-isle-yt-browse-preview-block="1"] ytm-thumbnail-overlay-loading-preview-renderer { display: none !important; visibility: hidden !important; opacity: 0 !important; pointer-events: none !important; }');
    rules.push('html[data-isle-yt-browse-preview-block="1"] ytd-thumbnail video, html[data-isle-yt-browse-preview-block="1"] ytd-rich-item-renderer video, html[data-isle-yt-browse-preview-block="1"] ytd-video-renderer video, html[data-isle-yt-browse-preview-block="1"] ytd-compact-video-renderer video, html[data-isle-yt-browse-preview-block="1"] ytm-media-item-renderer video, html[data-isle-yt-browse-preview-block="1"] ytm-rich-item-renderer video { opacity: 0 !important; visibility: hidden !important; pointer-events: none !important; }');
    el.textContent = rules.join('\\n');
  }

  function hideBlockedChannelLinkContainers() {
    document.querySelectorAll('a[href*="/@"], a[href*="/channel/"]').forEach(function(a) {
      const href = a.getAttribute('href') || '';
      if (!hrefBlocked(href)) return;
      const root = a.closest(LINK_CONTAINERS) || a.closest(CARD_SELECTORS) || a.parentElement;
      if (root) hideTile(root);
    });
  }

  function scanFeedTilesFull(root) {
    const scope = root || document;
    scope.querySelectorAll(CARD_SELECTORS).forEach(function(card) {
      if (isCardBlocked(card)) hideTile(card);
    });
  }

  function blockChannelHomePage() {
    const path = (location.pathname || '').toLowerCase();
    if (!path.includes('/@') && !path.includes('/channel/')) return;
    if (!hrefBlocked(location.pathname)) return;
    if (document.getElementById('isle-yt-channel-blocked-banner')) return;
    const banner = document.createElement('div');
    banner.id = 'isle-yt-channel-blocked-banner';
    banner.setAttribute('role', 'alert');
    banner.style.cssText = 'position:fixed;inset:0;z-index:2147483646;background:#111;color:#fff;display:flex;align-items:center;justify-content:center;padding:24px;text-align:center;font:16px -apple-system,sans-serif;';
    banner.textContent = 'Isle: 이 채널은 차단 목록에 있어요.';
    document.documentElement.appendChild(banner);
    hideTile(document.querySelector('ytd-app, ytm-app') || document.body);
  }

  function watchPageChannelMeta() {
    var meta = { channelId: '', channelName: '', videoId: '', videoTitle: '' };
    var href = location.href;
    var vm = href.match(/[?&]v=([\\w-]{11})/);
    if (vm) meta.videoId = vm[1];
    if (!meta.videoId) {
      var sm = href.match(/\\/shorts\\/([\\w-]{11})/);
      if (sm) meta.videoId = sm[1];
    }
    var m = href.match(/\\/channel\\/(UC[\\w-]+)/i);
    if (m) meta.channelId = m[1];
    if (!meta.channelId) {
      var h = href.match(/\\/@([\\w.\\-]+)/);
      if (h) meta.channelId = '@' + h[1];
    }
    var selectors = [
      'ytm-channel-name', 'ytd-channel-name a', 'ytd-video-owner-renderer a',
      '#channel-name a', 'yt-content-metadata-view-model a'
    ];
    for (var i = 0; i < selectors.length; i++) {
      var el = document.querySelector(selectors[i]);
      if (el) {
        meta.channelName = norm(el.textContent || el.innerText);
        if (meta.channelName) break;
      }
    }
    var link = document.querySelector('a[href*="/channel/"], a[href*="/@"], ytd-channel-name a');
    if (link) {
      var lh = link.getAttribute('href') || '';
      var cm = lh.match(/\\/channel\\/(UC[\\w-]+)/i);
      if (cm) meta.channelId = cm[1];
      var hm = lh.match(/\\/@([\\w.\\-]+)/);
      if (!meta.channelId && hm) meta.channelId = '@' + hm[1];
      if (!meta.channelName) meta.channelName = norm(link.textContent);
    }
    var titleSelectors = [
      'h1.ytd-watch-metadata yt-formatted-string',
      'h1 yt-formatted-string',
      '.slim-video-metadata-header-primary h1',
      'ytm-watch-metadata-header h1',
      'meta[name="title"]'
    ];
    for (var ti = 0; ti < titleSelectors.length; ti++) {
      var tel = document.querySelector(titleSelectors[ti]);
      if (!tel) continue;
      var raw = tel.getAttribute ? (tel.getAttribute('content') || tel.textContent || '') : (tel.textContent || '');
      meta.videoTitle = norm(raw.replace(/\\s*-\\s*YouTube\\s*\$/i, ''));
      if (meta.videoTitle) break;
    }
    return meta;
  }

  function isWatchMetaBlocked(meta) {
    if (meta.videoId && blockedVideoIds.indexOf(meta.videoId) >= 0) return true;
    if (urlBlocked(location.href || '')) return true;
    var id = norm(meta.channelId);
    if (id && block.ids.has(id)) return true;
    var bare = id.startsWith('@') ? id.slice(1) : id;
    if (bare && (block.handles.has(bare) || block.handles.has('@' + bare))) return true;
    if (nameBlocked(meta.channelName)) return true;
    if (meta.videoTitle && nameBlocked(meta.videoTitle)) return true;
    return false;
  }

  function enforceWatchPageBlock() {
    var href = location.href;
    if (!/[?&]v=[\\w-]{11}/.test(href) && href.indexOf('/shorts/') < 0) {
      window.__isleWatchBlockedPosted = false;
      return;
    }
    var meta = watchPageChannelMeta();
    if (!isWatchMetaBlocked(meta)) return;
    document.querySelectorAll('video').forEach(function(v) {
      try { v.pause(); v.removeAttribute('autoplay'); v.muted = true; } catch (e) {}
    });
    if (document.getElementById('isle-yt-watch-blocked-banner')) return;
    var banner = document.createElement('div');
    banner.id = 'isle-yt-watch-blocked-banner';
    banner.setAttribute('role', 'alert');
    banner.style.cssText = 'position:fixed;inset:0;z-index:2147483647;background:#111;color:#fff;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:24px;text-align:center;font:16px -apple-system,sans-serif;';
    banner.innerHTML = '<div style="font-size:20px;font-weight:600;margin-bottom:8px">차단한 콘텐츠예요</div><div style="opacity:0.75">Isle 프리셋·키워드·채널 차단에 해당합니다</div>';
    document.documentElement.appendChild(banner);
    if (window.IsleChannel && window.IsleChannel.postMessage && !window.__isleWatchBlockedPosted) {
      window.__isleWatchBlockedPosted = true;
      window.IsleChannel.postMessage(JSON.stringify({
        blockedNav: true,
        href: href,
        channelId: meta.channelId,
        channelName: meta.channelName,
        videoId: meta.videoId,
        videoTitle: meta.videoTitle || ''
      }));
    }
  }

  function apply() {
    if (document.visibilityState === 'hidden') return;
    syncBrowsePreviewState();
    injectChannelCss();
    scanFeedTilesFull(document);
    hideBlockedChannelLinkContainers();
    enforceBrowseFeedPlaybackBlock();
    blockChannelHomePage();
    enforceWatchPageBlock();
    document.querySelectorAll('ytd-channel-renderer, ytm-compact-channel-renderer').forEach(function(n) {
      if (isCardBlocked(n)) {
        hideTile(n);
        pauseVideosInNode(n);
      }
    });
  }

  function scheduleApply() {
    if (window.__isleBlockMoTimer) clearTimeout(window.__isleBlockMoTimer);
    window.__isleBlockMoTimer = setTimeout(function() {
      window.__isleBlockMoTimer = null;
      requestAnimationFrame(apply);
    }, DEBOUNCE_MS);
    // 순수 debounce만 쓰면 무한스크롤 홈 피드처럼 DOM이 계속 바뀌는 동안
    // 타이머가 계속 리셋돼 apply()가 영영 안 돌 수 있음(starvation) — 그동안
    // 새로 들어온 차단 채널 타일이 안 가려진 채로 계속 보이는 원인.
    // 별도 max-wait 타이머로 뮤테이션이 계속돼도 최소 주기마다 강제 실행.
    if (!window.__isleBlockMaxWaitTimer) {
      window.__isleBlockMaxWaitTimer = setTimeout(function() {
        window.__isleBlockMaxWaitTimer = null;
        requestAnimationFrame(apply);
      }, LIGHT ? 1100 : 900);
    }
  }

  function installFeedVideoPlayGuard() {
    if (window.__isleFeedVideoPlayGuard) return;
    window.__isleFeedVideoPlayGuard = true;
    document.addEventListener('play', function(e) {
      const v = e.target;
      if (!v || v.tagName !== 'VIDEO') return;
      if (!isWatchOrShortsPage()) {
        e.preventDefault();
        e.stopImmediatePropagation();
        suppressPreviewVideo(v);
        const previewCard = v.closest(CARD_SELECTORS);
        if (previewCard && isCardBlocked(previewCard)) hideTile(previewCard);
        return;
      }
      const card = v.closest(CARD_SELECTORS);
      if (!card || !isCardBlocked(card)) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      suppressPreviewVideo(v);
      hideTile(card);
      pauseVideosInNode(card);
    }, true);
    document.addEventListener('playing', function(e) {
      const v = e.target;
      if (!v || v.tagName !== 'VIDEO') return;
      if (!isWatchOrShortsPage()) {
        e.preventDefault();
        e.stopImmediatePropagation();
        suppressPreviewVideo(v);
        const previewCard = v.closest(CARD_SELECTORS);
        if (previewCard && isCardBlocked(previewCard)) hideTile(previewCard);
        return;
      }
      const card = v.closest(CARD_SELECTORS);
      if (!card || !isCardBlocked(card)) return;
      suppressPreviewVideo(v);
      hideTile(card);
    }, true);
  }

  function installPreviewTriggerGuard() {
    if (window.__islePreviewTriggerGuard) return;
    window.__islePreviewTriggerGuard = true;
    const events = ['pointerover', 'mouseover', 'mouseenter', 'pointerenter', 'touchstart', 'focusin'];
    const onPreviewTrigger = function(e) {
      if (isWatchOrShortsPage()) return;
      const t = e.target;
      const card = t && t.closest ? t.closest(CARD_SELECTORS) : null;
      if (card && isCardBlocked(card)) {
        e.preventDefault();
        e.stopImmediatePropagation();
        hideTile(card);
        suppressPreviewInNode(card);
        return;
      }
      const preview = t && t.closest ? t.closest(PREVIEW_SELECTORS) : null;
      if (preview) {
        e.preventDefault();
        e.stopImmediatePropagation();
        suppressPreviewInNode(preview);
      }
    };
    events.forEach(function(type) {
      document.addEventListener(type, onPreviewTrigger, true);
    });
  }

  // 전체화면 진입은 iOS 네이티브 플레이어 계층으로 올라가는 별도 이벤트라,
  // 이 파일의 나머지 차단 로직(카드 숨김·iframe 교체·주기적 sweep)이 전혀
  // 못 잡는다 — 한도 차단(YoutubeWebviewEnergy)에만 이 이벤트 가드가 있었고
  // 프리셋/키워드/채널 차단 쪽엔 없어서, "한도 없음" 상태에서 프리셋으로
  // 막은 영상도 전체화면을 누르면 그대로 재생됐다(2026-07-13 실사용 제보).
  // 전체화면에 들어가는 그 순간 다시 차단 여부를 확인해 즉시 pause+탈출한다.
  function installFullscreenGuard() {
    if (window.__isleFullscreenBlockGuard) return;
    window.__isleFullscreenBlockGuard = true;
    function exitAndPause(v) {
      try { if (v && typeof v.pause === 'function') v.pause(); } catch (e) {}
      try { if (v && typeof v.webkitExitFullscreen === 'function') v.webkitExitFullscreen(); } catch (e) {}
      try { if (document.fullscreenElement && document.exitFullscreen) document.exitFullscreen(); } catch (e) {}
      try { if (document.webkitFullscreenElement && document.webkitExitFullscreen) document.webkitExitFullscreen(); } catch (e) {}
    }
    function exitAndPauseBurst(v) {
      exitAndPause(v);
      setTimeout(function(){ exitAndPause(v); }, 60);
      setTimeout(function(){ exitAndPause(v); }, 150);
      setTimeout(function(){ exitAndPause(v); }, 300);
      setTimeout(function(){ exitAndPause(v); }, 600);
    }
    function onFullscreenEvent(e) {
      var video = (e.target && e.target.tagName === 'VIDEO') ? e.target : null;
      if (!video) video = document.fullscreenElement || document.webkitFullscreenElement || document.querySelector('video:-webkit-full-screen');
      var blockedNow = false;
      if (isWatchOrShortsPage()) {
        blockedNow = isWatchMetaBlocked(watchPageChannelMeta());
      } else if (video && video.closest) {
        var card = video.closest(CARD_SELECTORS);
        blockedNow = !!(card && isCardBlocked(card));
      }
      if (blockedNow) {
        try { if (e) { e.preventDefault(); e.stopImmediatePropagation(); } } catch (_) {}
        exitAndPauseBurst(video || e.target);
      }
    }
    function runImmediateFullscreenCheck() {
      var current = document.fullscreenElement || document.webkitFullscreenElement || document.querySelector('video:-webkit-full-screen');
      if (!current) return;
      onFullscreenEvent({ target: current });
    }
    document.addEventListener('webkitbeginfullscreen', onFullscreenEvent, true);
    document.addEventListener('fullscreenchange', onFullscreenEvent, true);
    document.addEventListener('webkitfullscreenchange', onFullscreenEvent, true);
    document.addEventListener('enterfullscreen', onFullscreenEvent, true);
    runImmediateFullscreenCheck();
    setTimeout(runImmediateFullscreenCheck, 0);
  }

  function installClickGuard() {
    if (window.__isleBlockClickGuard) return;
    window.__isleBlockClickGuard = true;
    document.addEventListener('click', function(e) {
      const a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
      if (!a) return;
      const card = a.closest(CARD_SELECTORS);
      if (card && isCardBlocked(card)) {
        e.preventDefault(); e.stopImmediatePropagation();
        hideTile(card);
        return;
      }
      const href = a.getAttribute('href') || '';
      if (hrefBlocked(href) || urlBlocked(href) || (videoIdFromHref(href) && blockedVideoIds.indexOf(videoIdFromHref(href)) >= 0)) {
        e.preventDefault(); e.stopImmediatePropagation();
        hideTile(a.closest(CARD_SELECTORS) || a);
      }
    }, true);
  }

  function startObserver() {
    if (window.__isleBlockObserver) return;
    window.__isleBlockObserver = new MutationObserver(function(muts) {
      if (document.visibilityState === 'hidden') return;
      for (let i = 0; i < muts.length; i++) {
        if (muts[i].addedNodes && muts[i].addedNodes.length) { scheduleApply(); return; }
      }
    });
    const root = document.body || document.documentElement;
    if (root) window.__isleBlockObserver.observe(root, { childList: true, subtree: true });
  }

  function installWatchPageVideoChangeGuard() {
    if (window.__isleWatchVideoGuard) return;
    window.__isleWatchVideoGuard = true;
    window.__isleLastWatchVideoId = '';
    function onWatchVideoChange() {
      var href = location.href || '';
      if (!/[?&]v=[\\w-]{11}/.test(href) && href.indexOf('/shorts/') < 0) {
        window.__isleLastWatchVideoId = '';
        window.__isleWatchBlockedPosted = false;
        return;
      }
      var meta = watchPageChannelMeta();
      if (!meta.videoId) return;
      // pushState 직후(setTimeout 0ms)엔 유튜브가 아직 새 영상의 채널명 DOM을
      // 렌더링 전이라 meta.channelId/channelName이 비어 있을 때가 많다 — 예전엔
      // videoId만 보고 "이 영상은 이미 확인함"으로 확정해버려서, 이 타이밍에
      // 걸리면 그 영상이 끝날 때까지 채널 체크가 영구히 스킵됐다(800ms 폴링도
      // 그냥 return). 이게 "채널 차단을 눌러도 가끔 안 먹힌다"는 실사용 제보의
      // 실제 원인(2026-07-14) — 채널 정보를 못 읽은 경우엔 이 videoId를 "확인
      // 완료"로 확정하지 않고, 채널 정보가 잡힐 때까지 다음 폴링(800ms)마다
      // 계속 재시도한다. __isleWatchBlockedPosted(차단 배너 postMessage
      // 중복방지 플래그, enforceWatchPageBlock 소유)와는 별개 플래그를 쓴다.
      var sameVideo = meta.videoId === window.__isleLastWatchVideoId;
      var hasChannelInfo = !!(meta.channelId || meta.channelName);
      if (sameVideo && window.__isleLastWatchVideoChannelResolved) return;
      if (hasChannelInfo) {
        window.__isleLastWatchVideoId = meta.videoId;
        window.__isleLastWatchVideoChannelResolved = true;
      } else if (!sameVideo) {
        window.__isleLastWatchVideoId = meta.videoId;
        window.__isleLastWatchVideoChannelResolved = false;
      }
      window.__isleWatchBlockedPosted = false;
      enforceWatchPageBlock();
      if (window.IsleChannel && window.IsleChannel.postMessage) {
        window.IsleChannel.postMessage(JSON.stringify({
          channelId: meta.channelId,
          channelName: meta.channelName,
          videoTitle: meta.videoTitle,
          videoId: meta.videoId
        }));
      }
    }
    window.__isleCheckWatchVideoChange = onWatchVideoChange;
    window.addEventListener('popstate', onWatchVideoChange);
    try {
      var _push = history.pushState;
      history.pushState = function() {
        var r = _push.apply(this, arguments);
        setTimeout(onWatchVideoChange, 0);
        return r;
      };
      var _replace = history.replaceState;
      history.replaceState = function() {
        var r = _replace.apply(this, arguments);
        setTimeout(onWatchVideoChange, 0);
        return r;
      };
    } catch (e) {}
    if (window.__isleWatchVideoInterval) clearInterval(window.__isleWatchVideoInterval);
    window.__isleWatchVideoInterval = setInterval(onWatchVideoChange, LIGHT ? 1000 : 800);
  }

  function startFeedPlaybackInterval() {
    if (window.__isleFeedPlaybackInterval) return;
    window.__isleFeedPlaybackInterval = setInterval(function() {
      if (document.visibilityState === 'hidden' || window.__isleBlocksPaused) return;
      enforceBrowseFeedPlaybackBlock();
    }, LIGHT ? 1800 : 1400);
  }

  function startIntervalSweep() {
    if (window.__isleBlockInterval) return;
    window.__isleBlockInterval = setInterval(function() {
      if (document.visibilityState === 'hidden' || window.__isleBlocksPaused) return;
      apply();
    }, LIGHT ? 7000 : 5000);
  }

  window.__islePauseBlocks = function() {
    if (window.__isleBlockObserver) { window.__isleBlockObserver.disconnect(); window.__isleBlockObserver = null; }
    if (window.__isleBlockInterval) { clearInterval(window.__isleBlockInterval); window.__isleBlockInterval = null; }
    if (window.__isleFeedPlaybackInterval) { clearInterval(window.__isleFeedPlaybackInterval); window.__isleFeedPlaybackInterval = null; }
    if (window.__isleWatchVideoInterval) { clearInterval(window.__isleWatchVideoInterval); window.__isleWatchVideoInterval = null; }
    if (window.__isleBlockMoTimer) { clearTimeout(window.__isleBlockMoTimer); window.__isleBlockMoTimer = null; }
    if (window.__isleBlockMaxWaitTimer) { clearTimeout(window.__isleBlockMaxWaitTimer); window.__isleBlockMaxWaitTimer = null; }
    window.__isleBlocksPaused = true;
  };
  window.__isleResumeBlocks = function() {
    window.__isleBlocksPaused = false;
    apply(); startObserver(); startIntervalSweep(); startFeedPlaybackInterval(); installWatchPageVideoChangeGuard(); installPreviewTriggerGuard(); installFullscreenGuard();
  };
  window.__isleApplyBlocks = apply;

  if (window.__isleBlockObserver) window.__isleBlockObserver.disconnect();
  if (window.__isleBlockInterval) clearInterval(window.__isleBlockInterval);
  if (window.__isleFeedPlaybackInterval) clearInterval(window.__isleFeedPlaybackInterval);
  if (window.__isleWatchVideoInterval) clearInterval(window.__isleWatchVideoInterval);

  if (!blockedIds.length && !blockedNames.length && !blockedVideoIds.length && !blockedKeywords.length && !blockedUrls.length) return;

  window.__isleBlocksPaused = false;
  installClickGuard();
  installPreviewTriggerGuard();
  installFullscreenGuard();
  installFeedVideoPlayGuard();
  installWatchPageVideoChangeGuard();
  apply();
  scheduleApply();
  setTimeout(scheduleApply, LIGHT ? 320 : 400);
  startObserver();
  startIntervalSweep();
  startFeedPlaybackInterval();
  document.addEventListener('visibilitychange', function() {
    if (document.visibilityState === 'visible') scheduleApply();
  });
})();
''';
  }
}
