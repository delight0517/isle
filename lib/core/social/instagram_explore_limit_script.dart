/// Instagram WebView — 탐색(Explore) 전용 안티-둠스크롤.
///
/// [InstagramReelsScrollGuardScript]는 영상(`<video>` play) 소비를 세지만,
/// 탐색 그리드는 사진 위주라 그 신호로는 못 잡는다. 탐색은 CSS 클래스가
/// 자주 바뀌어 그리드 아이템을 직접 셀 수 없으므로, 대신 두 가지 안정적인
/// 신호를 합쳐서 "포스트 몇 개를 봤는지"를 추정한다:
///   ① 포스트 상세로 이동(`/p/...`, `/reel/...` 링크 클릭·pushState) — 실제로
///      연 포스트 수
///   ② 스크롤 거리(뷰포트 높이 단위) — 그리드를 얼마나 넘겼는지
/// 둘 중 하나라도 임계치에 닿으면 [InstagramReelsScrollGuardScript]와 같은
/// 넛지·점점 강해지는 마찰 패턴을 그대로 재사용한다.
class InstagramExploreLimitScript {
  InstagramExploreLimitScript._();

  /// [threshold]는 첫 멈춤까지 허용하는 "포스트 열람 또는 스크롤 화면 수"
  /// (기본 15). 「조금만 더」마다 줄어든다. 탐색(`/explore`) 경로에서만 주입.
  static String install({required int threshold}) => '''
(function() {
  if (window.__isleIgExploreGuard) return;
  window.__isleIgExploreGuard = true;
  var BASE = $threshold;
  var threshold = BASE;
  var count = 0;
  var continues = 0;
  var scrolledViewports = 0;
  var lastScrollY = window.scrollY || 0;

  function bump() {
    count++;
    if (count >= threshold) showNudge();
  }

  function showNudge() {
    if (document.getElementById('isle-ig-explore-nudge')) return;
    var delay = Math.min(10, continues * 2); // 조금만 더를 누를수록 대기 ↑

    var ov = document.createElement('div');
    ov.id = 'isle-ig-explore-nudge';
    ov.style.cssText = 'position:fixed;inset:0;z-index:2147483647;background:rgba(8,20,30,0.94);'
      + 'display:flex;flex-direction:column;align-items:center;justify-content:center;'
      + 'color:#fff;font-family:-apple-system,BlinkMacSystemFont,sans-serif;padding:32px;text-align:center;';

    var msg = continues === 0
      ? '탐색 그만 둘러볼까요? 알고리즘이 계속 보여주는 것뿐, 찾던 게 아닐 수 있어요.'
      : (continues < 3
          ? '또 넘기고 있어요. 이쯤에서 빠져나오는 게 가장 쉬워요.'
          : '계속 넘기고 있어요. 지금 멈추는 게 좋겠어요.');

    ov.innerHTML = '<div style="font-size:46px;margin-bottom:16px;">🔎</div>'
      + '<div style="font-size:21px;font-weight:700;margin-bottom:10px;">벌써 ' + count + '개를 봤어요</div>'
      + '<div style="font-size:15px;opacity:0.82;line-height:1.55;margin-bottom:30px;max-width:300px;">' + msg + '</div>';

    var stop = document.createElement('button');
    stop.textContent = '그만 볼게요';
    stop.style.cssText = 'width:100%;max-width:320px;padding:15px;border:0;border-radius:14px;'
      + 'background:#E0C36A;color:#10202b;font-size:16px;font-weight:700;margin-bottom:12px;';
    stop.onclick = function() {
      ov.remove();
      if (history.length > 1) { history.back(); } else { location.href = 'https://www.instagram.com/'; }
    };

    var go = document.createElement('button');
    go.style.cssText = 'width:100%;max-width:320px;padding:13px;border:0;border-radius:14px;'
      + 'background:rgba(255,255,255,0.14);color:#fff;font-size:15px;opacity:0.6;';
    go.disabled = delay > 0;
    var remaining = delay;
    function renderGo() {
      go.textContent = remaining > 0 ? ('조금만 더 (' + remaining + ')') : '조금만 더';
      go.style.opacity = remaining > 0 ? '0.45' : '1';
    }
    renderGo();
    if (delay > 0) {
      var iv = setInterval(function() {
        remaining -= 1;
        if (remaining <= 0) { clearInterval(iv); go.disabled = false; }
        renderGo();
      }, 1000);
    }
    go.onclick = function() {
      if (go.disabled) return;
      continues += 1;
      threshold = Math.max(5, threshold - 4); // 다음 멈춤이 더 빨리 온다
      count = 0;
      scrolledViewports = 0;
      ov.remove();
    };

    ov.appendChild(stop);
    ov.appendChild(go);
    (document.body || document.documentElement).appendChild(ov);
  }

  // 신호 ① — 포스트/릴스 상세로 이동하는 링크 클릭(그리드 썸네일 열람).
  document.addEventListener('click', function(e) {
    var el = e.target;
    for (var i = 0; el && i < 6; i++) {
      if (el.tagName === 'A' && el.getAttribute) {
        var href = el.getAttribute('href') || '';
        if (/^\\/(p|reel|reels)\\//.test(href)) { bump(); return; }
      }
      el = el.parentElement;
    }
  }, true);

  // 신호 ② — 뷰포트 높이 단위 누적 스크롤 거리(그리드를 넘긴 화면 수).
  window.addEventListener('scroll', function() {
    var y = window.scrollY || 0;
    var dy = Math.abs(y - lastScrollY);
    lastScrollY = y;
    var vh = window.innerHeight || 800;
    scrolledViewports += dy / vh;
    if (scrolledViewports >= 1) {
      scrolledViewports -= 1;
      bump();
    }
  }, { passive: true });
})();
''';
}
