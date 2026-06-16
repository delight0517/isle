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

  /// 시청 한도·스케줄 잠금 enforcement — 페이지 안에 **상주 JS 가드**를 심는다.
  ///
  /// 오버레이는 시각적 scrim일 뿐 재생을 멈추지 못한다(특히 iOS 네이티브 풀스크린은
  /// Flutter 레이어 위에 떠 scrim이 아예 안 보임). Flutter 1초 tick에만 의존하면
  /// 풀스크린 진입·자동재생 직후 최대 1초 빈틈이 생기므로, 다음을 **무조건** 보장:
  ///  - `play`·`webkitbeginfullscreen`·`fullscreenchange`를 capture 단계로 즉시 가로채
  ///    `pause()`(풀스크린에서도 즉시 먹힘) → 오디오/영상 즉시 정지.
  ///  - 풀스크린 진입 시 `webkitExitFullscreen()`을 0/60/250ms로 반복 호출(일부 iOS의
  ///    진입 직후 exit 무시 레이스 회피).
  ///  - 페이지 자체 500ms 인터벌로 계속 enforce → tick 중단·전체 리로드돼도 유지.
  ///
  /// [blocked]=false면 가드를 비활성(플래그만 내림, 리스너/인터벌은 유지). [Volt]
  static String _enforcerJs(bool blocked) => '''
(function(){
  window.__isleBlockPlayback = $blocked;
  function enforce(){
    if (!window.__isleBlockPlayback) return;
    try {
      var vids = document.querySelectorAll('video');
      for (var i = 0; i < vids.length; i++) {
        var v = vids[i];
        try { if (!v.paused) v.pause(); } catch (e) {}
        try { if (v.webkitDisplayingFullscreen && v.webkitExitFullscreen) v.webkitExitFullscreen(); } catch (e) {}
      }
      try { if (document.fullscreenElement && document.exitFullscreen) document.exitFullscreen(); } catch (e) {}
    } catch (e) {}
  }
  window.__isleEnforcePlayback = enforce;
  if (!window.__isleEnforceInstalled) {
    window.__isleEnforceInstalled = true;
    var onPlay = function(){ enforce(); };
    var onFs = function(){
      if (!window.__isleBlockPlayback) return;
      enforce();
      setTimeout(enforce, 60);
      setTimeout(enforce, 250);
    };
    document.addEventListener('play', onPlay, true);
    document.addEventListener('playing', onPlay, true);
    document.addEventListener('webkitbeginfullscreen', onFs, true);
    document.addEventListener('fullscreenchange', onFs, true);
    document.addEventListener('webkitfullscreenchange', onFs, true);
    try { if (window.__isleEnforceTimer) clearInterval(window.__isleEnforceTimer); } catch (e) {}
    window.__isleEnforceTimer = setInterval(enforce, 500);
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
}
