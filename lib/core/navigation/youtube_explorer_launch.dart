import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../explorer/explorer_site.dart';
import '../youtube/youtube_webview_factory.dart';
import 'explorer_entry_guard.dart';

/// /youtube/browser 진입 — ExplorerEntryGuard 선검사 (로그인·설정 우회 방지)
class YoutubeExplorerLaunch {
  YoutubeExplorerLaunch._();

  static Future<bool> push(
    BuildContext context, {
    bool autoLogin = false,
    String? initialUrl,
  }) async {
    final startUrl = autoLogin
        ? YoutubeWebviewFactory.signInUrl()
        : (initialUrl?.trim().isNotEmpty == true
            ? initialUrl!.trim()
            : YoutubeWebviewFactory.homeUrl());
    final deny = ExplorerEntryGuard.denyMessageForSite(
      ExplorerSite.youtube,
      url: startUrl,
    );
    if (!ExplorerEntryGuard.allowOrSnack(
      context,
      deny,
      url: startUrl,
      site: ExplorerSite.youtube,
    )) {
      return false;
    }
    final params = <String, String>{};
    if (autoLogin) params['autologin'] = '1';
    if (initialUrl != null && initialUrl.trim().isNotEmpty) {
      params['url'] = initialUrl.trim();
    }
    final q = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    await context.push(q.isEmpty ? '/youtube/browser' : '/youtube/browser?$q');
    return true;
  }
}
