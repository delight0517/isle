import 'package:webview_flutter/webview_flutter.dart';

import '../services/isle_user_defaults.dart';
import 'google_search_block_cloak.dart';
import 'google_search_keyword_block_script.dart';
import 'google_surface_url_block_script.dart';
import 'safari_web_config.dart';

/// [방법 2] onPageStarted / onProgress — onPageFinished 이전에 클록·스윕 주입
class SearchBlockEarlyInject {
  SearchBlockEarlyInject._();

  static bool shouldInject(
    String url, {
    required List<String> keywords,
    required List<String> urls,
  }) {
    if (!SafariWebConfig.isGoogleSearchUrl(url)) return false;
    if (IsleUserDefaults.blockGoogleSearchKeywords && keywords.isNotEmpty) {
      return true;
    }
    if (IsleUserDefaults.blockGoogleSearchUrls && urls.isNotEmpty) return true;
    return false;
  }

  static Future<void> inject(
    WebViewController controller,
    String url, {
    List<String> keywords = const [],
    List<String> urls = const [],
  }) async {
    if (!shouldInject(url, keywords: keywords, urls: urls)) return;
    await controller.runJavaScript(GoogleSearchBlockCloak.install);
    if (IsleUserDefaults.blockGoogleSearchKeywords && keywords.isNotEmpty) {
      await controller.runJavaScript(
        GoogleSearchKeywordBlockScript.build(keywords),
      );
    }
    if (IsleUserDefaults.blockGoogleSearchUrls && urls.isNotEmpty) {
      final js = GoogleSurfaceUrlBlockScript.build(urls);
      if (js.isNotEmpty) await controller.runJavaScript(js);
    }
  }
}
