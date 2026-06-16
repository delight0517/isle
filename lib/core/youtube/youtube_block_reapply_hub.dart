import 'dart:async';

/// 앱 resume 시 WebView에 최신 차단 목록 재주입 — JS만 resume하면 목록이 낡을 수 있음
class YoutubeBlockReapplyHub {
  YoutubeBlockReapplyHub._();

  static final Set<Future<void> Function()> _handlers = {};

  static void register(Future<void> Function() handler) {
    _handlers.add(handler);
  }

  static void unregister(Future<void> Function() handler) {
    _handlers.remove(handler);
  }

  static Future<void> notifyAll() async {
    for (final h in _handlers.toList()) {
      try {
        await h();
      } catch (_) {}
    }
  }
}
