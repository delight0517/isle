/// Instagram WebView — 안티-둠스크롤 (점점 강해지는 마찰).
///
/// 릴스 탭 숨김([InstagramReelsHideScript])은 *진입*만 막을 뿐, 피드 안에서
/// 스크롤로 자동재생되는 영상의 무한 소비는 못 막는다. 이 스크립트는 스크롤로
/// 넘긴 영상(릴스 포함) 개수를 세서 임계치마다 멈춤 넛지를 띄우고 재생을 멈춘다.
///
/// 앱 의도(중독 차단·마찰 모델)에 맞춰 「조금만 더」를 누를수록 마찰이 강해진다:
///   ① 다음 멈춤까지 허용 개수가 줄어듦(예 10→7→4→3, 하한 3)
///   ② 「조금만 더」 버튼에 점점 긴 대기 시간(보안 키처럼) — 무심코 누르기 어렵게.
/// 페이지 상주(JS)라 SPA 전환·부분 리로드에도 유지된다.
class InstagramReelsScrollGuardScript {
  InstagramReelsScrollGuardScript._();

  /// [threshold]는 첫 멈춤까지 허용하는 영상 수(기본 10). 「조금만 더」마다 줄어든다.
  static String install({required int threshold}) => '''
(function() {
  if (window.__isleIgScrollGuard) return;
  window.__isleIgScrollGuard = true;
  var BASE = $threshold;
  var threshold = BASE;
  var count = 0;
  var continues = 0;
  var lastEl = null;
  var lastAt = 0;

  function pauseAll() {
    var vs = document.querySelectorAll('video');
    for (var i = 0; i < vs.length; i++) { try { vs[i].pause(); } catch (e) {} }
  }

  function showNudge() {
    if (document.getElementById('isle-ig-nudge')) return;
    pauseAll();
    var delay = Math.min(10, continues * 2); // 조금만 더를 누를수록 대기 ↑

    var ov = document.createElement('div');
    ov.id = 'isle-ig-nudge';
    ov.style.cssText = 'position:fixed;inset:0;z-index:2147483647;background:rgba(8,20,30,0.94);'
      + 'display:flex;flex-direction:column;align-items:center;justify-content:center;'
      + 'color:#fff;font-family:-apple-system,BlinkMacSystemFont,sans-serif;padding:32px;text-align:center;';

    var msg = continues === 0
      ? '잠깐 멈춰볼까요? 지금 이게 정말 보고 싶은 건지, 아니면 그냥 손가락이 움직이는 건지 생각해봐요.'
      : (continues < 3
          ? '또 넘기고 있어요. 이쯤에서 빠져나오는 게 가장 쉬워요.'
          : '계속 넘기고 있어요. 지금 멈추는 게 좋겠어요.');

    ov.innerHTML = '<div style="font-size:46px;margin-bottom:16px;">🌿</div>'
      + '<div style="font-size:21px;font-weight:700;margin-bottom:10px;">벌써 ' + count + '개를 넘겼어요</div>'
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
      threshold = Math.max(3, threshold - 3); // 다음 멈춤이 더 빨리 온다
      count = 0;
      ov.remove();
    };

    ov.appendChild(stop);
    ov.appendChild(go);
    (document.body || document.documentElement).appendChild(ov);
  }

  // 스크롤로 새 영상이 재생될 때마다 +1 (같은 영상 짧은 재생 반복은 1.5초 디바운스).
  document.addEventListener('play', function(e) {
    var t = e.target;
    if (!t || t.tagName !== 'VIDEO') return;
    var now = Date.now();
    if (t === lastEl && now - lastAt < 1500) return;
    lastEl = t;
    lastAt = now;
    count++;
    if (count >= threshold) showNudge();
  }, true);
})();
''';
}
