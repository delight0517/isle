import 'dart:async' show unawaited;

import 'package:webview_flutter/webview_flutter.dart';

import '../services/isle_app_log_service.dart';
import 'youtube_block_reapply_hub.dart';
import 'youtube_webview_factory.dart';

/// 활성 WebView 등록 — 앱 백그라운드 시 JS 차단 루프 정지 [Volt]
class YoutubeWebviewEnergy {
  YoutubeWebviewEnergy._();

  static final Set<WebViewController> _active = {};

  static void register(WebViewController controller) {
    _active.add(controller);
  }

  static void unregister(WebViewController controller) {
    _active.remove(controller);
    unawaited(teardown(controller));
  }

  static Future<void> teardown(WebViewController? controller) async {
    if (controller == null) return;
    try {
      await YoutubeWebviewFactory.teardownBlockScript(controller);
    } catch (_) {}
  }

  /// 앱이 백그라운드로 갈 때 — MutationObserver·interval 정지
  static Future<void> pauseAll() async {
    for (final c in _active.toList()) {
      try {
        await c.runJavaScript('''
          if (typeof window.__islePauseBlocks === 'function') window.__islePauseBlocks();
        ''');
      } catch (e) {
        IsleAppLogService.log('WebView pause: $e', level: IsleLogLevel.debug);
      }
    }
  }

  static Future<void> resumeAll() async {
    for (final c in _active.toList()) {
      try {
        await c.runJavaScript('''
          if (typeof window.__isleResumeBlocks === 'function') window.__isleResumeBlocks();
        ''');
      } catch (_) {}
    }
    await YoutubeBlockReapplyHub.notifyAll();
  }

  /// 시청 한도·채널 차단 enforcement — 페이지 안에 **상주 JS 가드**를 심는다.
  ///
  /// 오버레이는 시각적 scrim일 뿐 재생을 멈추지 못한다(특히 iOS 네이티브 풀스크린은
  /// Flutter 레이어 위에 떠 scrim이 아예 안 보임). Flutter 1초 tick에만 의존하면
  /// 풀스크린 진입·자동재생 직후 최대 1초 빈틈이 생기므로, 다음을 **무조건** 보장:
  ///  - `play`·`webkitbeginfullscreen`·`fullscreenchange`·`enterfullscreen`을
  ///    capture 단계로 즉시 가로채 `pause()` → 오디오/영상 즉시 정지.
  ///  - 풀스크린 진입 시 0/60/150/300/600ms 5단계 반복 exit(연타로 진입해도 차단).
  ///  - 풀스크린 연타 감지: 300ms 이내 재진입 시 추가 exit burst.
  ///  - 차단 중에만 페이지 자체 150ms 인터벌로 계속 enforce.
  ///
  /// [blocked]=false면 가드를 비활성하고 interval을 해제한다. 리스너는 남지만
  /// 플래그로 즉시 return하므로 정상 시청 중 DOM sweep을 계속 돌리지 않는다. [Volt]
  static String _enforcerJs(bool blocked) => '''
(function(){
  window.__isleBlockPlayback = $blocked;
  function clearEnforceTimer(){
    try {
      if (window.__isleEnforceTimer) {
        clearInterval(window.__isleEnforceTimer);
        window.__isleEnforceTimer = null;
      }
    } catch (e) {}
  }
  function enforce(){
    if (!window.__isleBlockPlayback) return;
    try {
      var vids = document.querySelectorAll('video');
      for (var i = 0; i < vids.length; i++) {
        var v = vids[i];
        try { if (!v.paused) { v.pause(); } } catch (e) {}
        try { if (v.webkitDisplayingFullscreen && v.webkitExitFullscreen) v.webkitExitFullscreen(); } catch (e) {}
      }
      try { if (document.fullscreenElement && document.exitFullscreen) document.exitFullscreen(); } catch (e) {}
      try { if (document.webkitFullscreenElement && document.webkitExitFullscreen) document.webkitExitFullscreen(); } catch (e) {}
    } catch (e) {}
  }
  function exitFullscreenBurst(){
    // 5단계 지연 exit — 풀스크린 연타로도 탈출 보장
    enforce();
    setTimeout(enforce, 60);
    setTimeout(enforce, 150);
    setTimeout(enforce, 300);
    setTimeout(enforce, 600);
  }
  window.__isleEnforcePlayback = enforce;
  if (!window.__isleBlockPlayback) {
    clearEnforceTimer();
    return;
  }
  if (!window.__isleEnforceInstalled) {
    window.__isleEnforceInstalled = true;
    var lastFsEnter = 0;
    var onPlay = function(e){
      if (!window.__isleBlockPlayback) return;
      try { e.stopImmediatePropagation(); } catch(_) {}
      enforce();
    };
    var onFs = function(){
      if (!window.__isleBlockPlayback) return;
      var now = Date.now ? Date.now() : 0;
      if (now - lastFsEnter < 300) {
        // 연타 감지: 추가 burst
        exitFullscreenBurst();
        setTimeout(exitFullscreenBurst, 400);
      } else {
        exitFullscreenBurst();
      }
      lastFsEnter = now;
    };
    document.addEventListener('play', onPlay, true);
    document.addEventListener('playing', onPlay, true);
    document.addEventListener('webkitbeginfullscreen', onFs, true);
    document.addEventListener('fullscreenchange', onFs, true);
    document.addEventListener('webkitfullscreenchange', onFs, true);
    document.addEventListener('enterfullscreen', onFs, true);
  }
  if (!window.__isleEnforceTimer) {
    // 150ms 인터벌 — 차단 중에만 연타 빈틈 최소화
    window.__isleEnforceTimer = setInterval(enforce, 150);
  }
  enforce();
})();
''';

  /// 잠금 상태 토글 + 상주 가드 보장(idempotent). 매 tick·페이지 ready에서 호출 가능.
  static Future<void> setPlaybackBlocked(
    WebViewController? controller,
    bool blocked,
  ) async {
    if (controller == null) return;
    try {
      await controller.runJavaScript(_enforcerJs(blocked));
    } catch (_) {}
  }

  /// True only when a real `<video>` element is currently playing in a visible page.
  /// This keeps browsing, paused video pages, and app/background audio out of watch limits.
  static Future<bool> isVideoActivelyPlaying(
    WebViewController? controller,
  ) async {
    if (controller == null) return false;
    try {
      final raw = await controller.runJavaScriptReturningResult(r'''
(function(){
  try {
    if (document.visibilityState && document.visibilityState !== 'visible') {
      return false;
    }
    var vids = document.querySelectorAll('video');
    for (var i = 0; i < vids.length; i++) {
      var v = vids[i];
      var rect = null;
      try { rect = v.getBoundingClientRect(); } catch (_) {}
      var visible = !rect || (
        rect.width > 2 &&
        rect.height > 2 &&
        rect.bottom > 0 &&
        rect.right > 0 &&
        rect.top < (window.innerHeight || document.documentElement.clientHeight || 0) &&
        rect.left < (window.innerWidth || document.documentElement.clientWidth || 0)
      );
      if (
        visible &&
        !v.paused &&
        !v.ended &&
        v.readyState >= 2 &&
        v.currentTime > 0
      ) {
        return true;
      }
    }
  } catch (_) {}
  return false;
})()
''');
      if (raw is bool) return raw;
      final s = raw.toString().toLowerCase().trim();
      return s == 'true' || s == '1';
    } catch (_) {
      return false;
    }
  }
}
