/// 시청 중 페이지 — 채널 + 영상 제목
class YoutubeWatchProbeScript {
  YoutubeWatchProbeScript._();

  static const String probeAndPost = '''
(function() {
  function norm(s) { return (s || '').trim(); }
  var id = '';
  var name = '';
  var videoTitle = '';
  var videoId = '';
  var href = location.href;

  var vm = href.match(/[?&]v=([\\w-]{11})/);
  if (vm) videoId = vm[1];
  if (!videoId) {
    var sm = href.match(/\\/shorts\\/([\\w-]{11})/);
    if (sm) videoId = sm[1];
  }

  var titleSel = [
    'h1.ytd-watch-metadata yt-formatted-string',
    'h1.ytd-video-primary-info-renderer',
    'h1.title',
    'ytm-watch-metadata h1',
    'meta[property="og:title"]'
  ];
  for (var i = 0; i < titleSel.length; i++) {
    var el = document.querySelector(titleSel[i]);
    if (el) {
      videoTitle = norm(el.getAttribute && el.getAttribute('content') ? el.getAttribute('content') : (el.textContent || el.innerText));
      if (videoTitle) break;
    }
  }

  var m = href.match(/\\/channel\\/(UC[\\w-]+)/i);
  if (m) id = m[1];
  if (!id) {
    var h = href.match(/\\/@([\\w.\\-]+)/);
    if (h) id = '@' + h[1];
  }

  var selectors = [
    'ytm-channel-name',
    'ytd-channel-name a',
    'ytd-video-owner-renderer a',
    '#channel-name a',
    'yt-content-metadata-view-model a'
  ];
  for (var i = 0; i < selectors.length; i++) {
    var el = document.querySelector(selectors[i]);
    if (el) {
      name = norm(el.textContent || el.innerText);
      if (name) break;
    }
  }

  if (!id) {
    var link = document.querySelector('a[href*="/channel/"], a[href*="/@"], ytd-channel-name a');
    if (link) {
      var lh = link.getAttribute('href') || '';
      var cm = lh.match(/\\/channel\\/(UC[\\w-]+)/i);
      if (cm) id = cm[1];
      var hm = lh.match(/\\/@([\\w.\\-]+)/);
      if (!id && hm) id = '@' + hm[1];
      if (!name) name = norm(link.textContent);
    }
  }

  if (window.IsleChannel && window.IsleChannel.postMessage) {
    window.IsleChannel.postMessage(JSON.stringify({
      channelId: id,
      channelName: name,
      videoTitle: videoTitle,
      videoId: videoId
    }));
  }
})();
''';
}
