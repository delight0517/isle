import 'package:webview_flutter/webview_flutter.dart';

import '../safety/content_safety_guard.dart';
import '../services/isle_user_defaults.dart';
import '../youtube/block_keyword_policy.dart';
import 'google_search_block_cloak.dart';
import 'google_search_keyword_block_script.dart';
import 'google_surface_url_block_script.dart';
import 'safari_web_config.dart';

/// [방법 2] onPageStarted / onProgress — onPageFinished 이전에 클록·스윕 주입
class SearchBlockEarlyInject {
  SearchBlockEarlyInject._();

  static List<String> get _adultAlwaysKws => ContentSafetyGuard.enabled
      ? ContentSafetyGuard.builtInAdultSearchKeywords
      : const [];

  static bool shouldInject(
    String url, {
    required List<String> keywords,
    required List<String> urls,
  }) {
    // Google 이미지 탭(tbm=isch)도 early inject 대상
    if (!SafariWebConfig.isGoogleSearchUrl(url)) return false;
    // 성인 내장 키워드만 있어도 주입
    if (IsleUserDefaults.blockGoogleSearchKeywords && _adultAlwaysKws.isNotEmpty) {
      return true;
    }
    final searchQuery = SafariWebConfig.searchQueryFromUrl(url);
    final googleKeywords = BlockKeywordPolicy.forGoogleSearchInject(
      keywords,
      searchQuery: searchQuery,
    );
    if (IsleUserDefaults.blockGoogleSearchKeywords && googleKeywords.isNotEmpty) {
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
    final searchQuery = SafariWebConfig.searchQueryFromUrl(url);
    final googleKeywords = BlockKeywordPolicy.forGoogleSearchInject(
      keywords,
      searchQuery: searchQuery,
    );
    final adultKws = _adultAlwaysKws;
    await controller.runJavaScript(GoogleSearchBlockCloak.install);
    if (IsleUserDefaults.blockGoogleSearchKeywords &&
        (googleKeywords.isNotEmpty || adultKws.isNotEmpty)) {
      await controller.runJavaScript(
        GoogleSearchKeywordBlockScript.build(
          googleKeywords,
          searchQuery: searchQuery,
          alwaysBlockKeywords: adultKws,
        ),
      );
    }
    if (IsleUserDefaults.blockGoogleSearchUrls && urls.isNotEmpty) {
      final js = GoogleSurfaceUrlBlockScript.build(urls);
      if (js.isNotEmpty) await controller.runJavaScript(js);
    }
  }
}
