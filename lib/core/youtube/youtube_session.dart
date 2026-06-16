import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/isle_app_log_service.dart';
import 'models/youtube_page_channel.dart';
import 'youtube_webview_energy.dart';

typedef YoutubeUrlHandler = void Function(String url);
typedef YoutubeVoidHandler = void Function();
typedef YoutubeProbeHandler = void Function(String raw);

/// 유튜브 WebView — 피드로 나가도 세션 유지(백그라운드 재생)
class YoutubeSession extends ChangeNotifier {
  YoutubeSession._();
  static final YoutubeSession instance = YoutubeSession._();

  WebViewController? parkedController;
  bool minimized = false;
  String currentUrl = '';
  String displayTitle = '';
  YoutubePageChannel probed = const YoutubePageChannel(channelId: '', channelName: '');

  YoutubeUrlHandler? onUrlChanged;
  YoutubeVoidHandler? onPageReady;
  YoutubeProbeHandler? onChannelProbe;

  bool get hasParkedSession => minimized && parkedController != null;

  void wireController(WebViewController controller) {
    controller.setNavigationDelegate(
      NavigationDelegate(
        onUrlChange: (c) {
          final url = c.url;
          if (url != null && url.isNotEmpty) {
            currentUrl = url;
            onUrlChanged?.call(url);
          }
        },
        onPageFinished: (_) => onPageReady?.call(),
      ),
    );
  }

  void clearHandlers() {
    onUrlChanged = null;
    onPageReady = null;
    onChannelProbe = null;
  }

  void park({
    required WebViewController controller,
    required String url,
    required String title,
    YoutubePageChannel? channel,
  }) {
    parkedController = controller;
    minimized = true;
    currentUrl = url;
    displayTitle = title;
    if (channel != null) probed = channel;
    IsleAppLogService.log(
      'YouTube minimized → feed (background play). url=$url title=$title',
    );
    notifyListeners();
  }

  void unparkForRoute() {
    minimized = false;
    IsleAppLogService.log('YouTube resumed from minimized. url=$currentUrl');
    notifyListeners();
  }

  void quit() {
    final c = parkedController;
    if (c != null) {
      YoutubeWebviewEnergy.unregister(c);
      try {
        c.runJavaScript(
          "document.querySelectorAll('video').forEach(function(v){v.pause();});",
        );
      } catch (_) {}
    }
    parkedController = null;
    minimized = false;
    currentUrl = '';
    displayTitle = '';
    probed = const YoutubePageChannel(channelId: '', channelName: '');
    clearHandlers();
    IsleAppLogService.log('YouTube session quit');
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
}
