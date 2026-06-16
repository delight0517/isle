/// 현재 유튜브 페이지에서 채널 ID·이름 추출 (모바일/데스크톱 DOM)
class YoutubeChannelProbeScript {
  YoutubeChannelProbeScript._();

  static const String probeAndPost = '''
(function() {
  function norm(s) { return (s || '').trim(); }
  var id = '';
  var name = '';
  var href = location.href;

  var m = href.match(/\\/channel\\/(UC[\\w-]+)/i);
  if (m) id = m[1];
  if (!id) {
    var h = href.match(/\\/@([\\w.\\-]+)/);
    if (h) id = '@' + h[1];
  }
  if (!id) {
    var c = href.match(/\\/c\\/([\\w.\\-]+)/i);
    if (c) id = c[1];
  }

  var selectors = [
    'ytm-channel-name',
    'ytm-profile-header-renderer .channel-name',
    'ytd-channel-name a',
    'ytd-video-owner-renderer a',
    '#channel-name a',
    '.slim-owner-channel-name',
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
    var link = document.querySelector(
      'a[href*="/channel/"], a[href*="/@"], ytd-channel-name a, ytm-channel-name a'
    );
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
      channelName: name
    }));
  }
})();
''';
}
