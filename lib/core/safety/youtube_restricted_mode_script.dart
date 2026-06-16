/// YouTube Restricted Mode — WebView 쿠키·메타 (안전 모드 ON일 때만 주입)
class YoutubeRestrictedModeScript {
  YoutubeRestrictedModeScript._();

  static const install = '''
(function() {
  if (window.__isleYtRestricted) return;
  window.__isleYtRestricted = true;
  try {
    var cookie = 'PREF=f6=8&f2=8000000; path=/; domain=.youtube.com; max-age=31536000; SameSite=Lax';
    document.cookie = cookie;
    var m = document.querySelector('meta[name="referrer"]');
    if (!m) {
      m = document.createElement('meta');
      m.name = 'referrer';
      document.head.appendChild(m);
    }
    m.content = 'strict-origin-when-cross-origin';
  } catch (e) {}
})();
''';
}
