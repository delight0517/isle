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
    // 피드 스크롤 중에도 이 옵저버가 document 전체를 계속 관찰해서, 매 DOM
    // mutation(무한 스크롤 로딩·영상 자동재생 상태 변화 등)마다 콜백이 불려
    // JS 메인 스레드가 눌리는 게 실사용에서 확인된 랙·"피드가 한번에 여러 개
    // 넘어가는" 버벅임의 원인이었다(2026-07-20). revealComments 자체는
    // isPostPath()로 걸러도, 콜백 호출 자체의 브릿지 비용은 그대로 남는다.
    // requestAnimationFrame으로 묶어서 한 프레임에 최대 1번만 실행한다.
    var isleCommentsRafPending = false;
    var isleCommentsObserverCallback = function() {
      if (isleCommentsRafPending) return;
      isleCommentsRafPending = true;
      requestAnimationFrame(function() {
        isleCommentsRafPending = false;
        revealComments();
      });
    };
    window.__isleIgCommentsObserver = new MutationObserver(isleCommentsObserverCallback);
    window.__isleIgCommentsObserver.observe(document.documentElement, { childList: true, subtree: true });
  }
})();
''';
}
