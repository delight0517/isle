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
    final ids = blockedChannels.map((e) => e.channelId).where((e) => e.isNotEmpty).toList();
    final names = blockedChannels.map((e) => e.channelName).where((e) => e.isNotEmpty).toList();
    final vids = blockedVideoIds.map((e) => e.trim()).where((e) => e.length == 11).toList();
    final kws = blockedKeywords.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
    final urls = blockedUrls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

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
  const DEBOUNCE_MS = LIGHT ? 650 : 500;

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
    const nameEl = card.querySelector('#channel-name, .ytm-badge-and-byline-renderer, .ytd-channel-name, .compact-media-item-headline');
    if (nameEl) meta.channelName = norm(nameEl.textContent || '');
    return meta;
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

  function apply() {
    if (document.visibilityState === 'hidden') return;
    injectChannelCss();
    scanFeedTilesFull(document);
    hideBlockedChannelLinkContainers();
    blockChannelHomePage();
    document.querySelectorAll('ytd-channel-renderer, ytm-compact-channel-renderer').forEach(function(n) {
      if (isCardBlocked(n)) hideTile(n);
    });
  }

  function scheduleApply() {
    if (window.__isleBlockMoTimer) clearTimeout(window.__isleBlockMoTimer);
    window.__isleBlockMoTimer = setTimeout(function() {
      window.__isleBlockMoTimer = null;
      requestAnimationFrame(apply);
    }, DEBOUNCE_MS);
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

  function startIntervalSweep() {
    if (window.__isleBlockInterval) return;
    window.__isleBlockInterval = setInterval(function() {
      if (document.visibilityState === 'hidden' || window.__isleBlocksPaused) return;
      apply();
    }, LIGHT ? 2800 : 2200);
  }

  window.__islePauseBlocks = function() {
    if (window.__isleBlockObserver) { window.__isleBlockObserver.disconnect(); window.__isleBlockObserver = null; }
    if (window.__isleBlockInterval) { clearInterval(window.__isleBlockInterval); window.__isleBlockInterval = null; }
    window.__isleBlocksPaused = true;
  };
  window.__isleResumeBlocks = function() {
    window.__isleBlocksPaused = false;
    apply(); startObserver(); startIntervalSweep();
  };
  window.__isleApplyBlocks = apply;

  if (window.__isleBlockObserver) window.__isleBlockObserver.disconnect();
  if (window.__isleBlockInterval) clearInterval(window.__isleBlockInterval);

  if (!blockedIds.length && !blockedNames.length && !blockedVideoIds.length && !blockedKeywords.length && !blockedUrls.length) return;

  window.__isleBlocksPaused = false;
  installClickGuard();
  apply();
  scheduleApply();
  setTimeout(scheduleApply, LIGHT ? 900 : 400);
  startObserver();
  startIntervalSweep();
  document.addEventListener('visibilitychange', function() {
    if (document.visibilityState === 'visible') scheduleApply();
  });
})();
''';
  }
}
