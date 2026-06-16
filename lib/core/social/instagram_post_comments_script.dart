/// Instagram DM 모드 — 공유 포스트(/p/)에서 댓글 영역까지 스크롤·표시
class InstagramPostCommentsScript {
  InstagramPostCommentsScript._();

  static const String install = '''
(function() {
  if (window.__isleIgCommentsInstalled) return;
  window.__isleIgCommentsInstalled = true;

  function isPostPath() {
    var p = (location.pathname || '').toLowerCase();
    // 릴스·IGTV 전체화면 뷰어에는 댓글 강제 주입 금지 — DM 뒤로가기·재생 UI 충돌
    return p.startsWith('/p/');
  }

  function revealComments() {
    if (!isPostPath()) return;

    // 댓글 버튼·섹션 숨김 방지
    document.querySelectorAll(
      'a[href*="/comments"], button[aria-label*="comment" i], button[aria-label*="댓글" i], ' +
      'span[aria-label*="comment" i], span[aria-label*="댓글" i], ul[role="list"]'
    ).forEach(function(el) {
      if (el && el.style) {
        el.style.display = '';
        el.style.visibility = 'visible';
        el.style.pointerEvents = 'auto';
      }
    });

    // 「댓글 보기」류 버튼 자동 탭 (1회)
    if (!window.__isleIgCommentsExpanded) {
      var btn = document.querySelector(
        'button[aria-label*="comment" i], button[aria-label*="댓글" i], ' +
        'span[role="button"][aria-label*="comment" i]'
      );
      if (btn && typeof btn.click === 'function') {
        window.__isleIgCommentsExpanded = true;
        try { btn.click(); } catch (e) {}
      }
    }

    // 댓글 목록이 아래에 있으면 살짝 스크롤
    var main = document.querySelector('main[role="main"], main, article');
    if (main && main.scrollHeight > main.clientHeight + 80) {
      main.scrollTop = Math.min(main.scrollHeight * 0.35, main.scrollHeight);
    }
  }

  revealComments();
  setTimeout(revealComments, 400);
  setTimeout(revealComments, 1200);
  if (!window.__isleIgCommentsObserver) {
    window.__isleIgCommentsObserver = new MutationObserver(revealComments);
    window.__isleIgCommentsObserver.observe(document.documentElement, { childList: true, subtree: true });
  }
})();
''';
}
