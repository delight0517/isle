/// 현재 WebView 페이지에서 링크·본문 URL 추출 (Firefox 콘솔 북마클릿 대체)
class PageLinkHarvestScript {
  PageLinkHarvestScript._();

  /// `runJavaScriptReturningResult` — JSON 문자열 반환
  static const harvest = r'''
(function() {
  function abs(href) {
    if (!href) return null;
    try {
      var u = new URL(href, location.href);
      if (u.protocol !== 'http:' && u.protocol !== 'https:') return null;
      return u.href;
    } catch (e) { return null; }
  }
  function hostOf(url) {
    try { return new URL(url).hostname.replace(/^www\./i, '').toLowerCase(); }
    catch (e) { return ''; }
  }
  var seen = {};
  var out = [];
  function push(url, text) {
    if (!url) return;
    var key = url.toLowerCase();
    if (seen[key]) return;
    seen[key] = 1;
    out.push({
      url: url,
      text: (text || '').trim().slice(0, 160),
      host: hostOf(url)
    });
  }
  var anchors = document.querySelectorAll('a[href], area[href]');
  for (var i = 0; i < anchors.length; i++) {
    var a = anchors[i];
    push(abs(a.getAttribute('href')), a.innerText || a.textContent || '');
  }
  var dataEls = document.querySelectorAll('[data-href],[data-url]');
  for (var j = 0; j < dataEls.length; j++) {
    var el = dataEls[j];
    var dh = el.getAttribute('data-href') || el.getAttribute('data-url');
    push(abs(dh), el.innerText || el.textContent || '');
  }
  var body = document.body ? (document.body.innerText || '') : '';
  var re = /https?:\/\/[^\s"'<>]+/gi;
  var m;
  while ((m = re.exec(body)) !== null) {
    var raw = m[0].replace(/[.,;:!?)]+$/, '');
    push(abs(raw), '');
  }
  return JSON.stringify(out);
})()
''';
}
