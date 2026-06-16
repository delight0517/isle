import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/isle_app_log_service.dart';
import 'models/youtube_page_channel.dart';
import 'youtube_podcast_audio_script.dart';
import 'youtube_webview_energy.dart';

/// 음성 모드 — 화면을 나가도 1×1 WebView로 재생 유지
class YoutubePodcastSession extends ChangeNotifier {
  YoutubePodcastSession._();
  static final YoutubePodcastSession instance = YoutubePodcastSession._();

  WebViewController? parkedController;
  bool minimized = false;
  String currentUrl = '';
  String displayTitle = '';
  YoutubePageChannel meta = const YoutubePageChannel(channelId: '', channelName: '');
  bool dartPaused = false;

  bool get hasParkedSession => minimized && parkedController != null;

  void park({
    required WebViewController controller,
    required String url,
    required String title,
    YoutubePageChannel? channel,
    bool paused = false,
  }) {
    parkedController = controller;
    minimized = true;
    currentUrl = url;
    displayTitle = title;
    dartPaused = paused;
    if (channel != null) meta = channel;
    IsleAppLogService.log('YouTube podcast parked (background listen). url=$url');
    notifyListeners();
  }

  void unparkForRoute() {
    minimized = false;
    notifyListeners();
  }

  WebViewController? takeControllerForRoute() {
    final c = parkedController;
    if (c != null && minimized) {
      unparkForRoute();
      return c;
    }
    return null;
  }

  Future<void> quit() async {
    final c = parkedController;
    if (c != null) {
      YoutubeWebviewEnergy.unregister(c);
      try {
        await c.runJavaScript(YoutubePodcastAudioScript.teardown);
      } catch (_) {}
    }
    parkedController = null;
    minimized = false;
    currentUrl = '';
    displayTitle = '';
    meta = const YoutubePageChannel(channelId: '', channelName: '');
    dartPaused = false;
    IsleAppLogService.log('YouTube podcast session quit');
    notifyListeners();
  }
}
