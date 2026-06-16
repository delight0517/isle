/// 현재 브런치 글/프로필에서 작가 handle 추출
class BrunchAuthorProbeScript {
  BrunchAuthorProbeScript._();

  static const probeAndPost = '''
(function() {
  var handle = '';
  var name = '';
  var m = location.pathname.match(/@([\\w.-]+)/);
  if (m) handle = m[1];
  var og = document.querySelector('meta[property="brunch:author"]');
  if (og) name = og.content || '';
  var prof = document.querySelector('.profile_info .name, .author_name, [class*="AuthorName"]');
  if (prof) name = (prof.innerText || '').trim();
  if (!handle) {
    var links = document.querySelectorAll('a[href*="/@"]');
    for (var i = 0; i < links.length; i++) {
      var hm = links[i].href.match(/@([\\w.-]+)/);
      if (hm) { handle = hm[1]; break; }
    }
  }
  if (window.IsleBrunchAuthor) {
    window.IsleBrunchAuthor.postMessage(JSON.stringify({ handle: handle, name: name, url: location.href }));
  }
})();
''';
}
