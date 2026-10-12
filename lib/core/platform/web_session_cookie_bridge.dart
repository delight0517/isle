import 'dart:io';

import 'package:flutter/services.dart';

/// YouTube·Instagram WebView 세션 쿠키 — 네이티브 WKHTTPCookieStore / CookieManager
class WebSessionCookieBridge {
  WebSessionCookieBridge._();

  static const _channel = MethodChannel('com.isle.app/web_session');

  static bool get supported => Platform.isIOS || Platform.isAndroid;

  static Future<List<Map<String, dynamic>>> exportCookies() async {
    if (!supported) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('exportCookies');
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on MissingPluginException {
      return const [];
    }
  }

  static Future<void> importCookies(List<Map<String, dynamic>> cookies) async {
    if (!supported || cookies.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('importCookies', cookies);
    } on MissingPluginException {
      // no-op
    }
  }

  /// 만료·손상 Instagram/YouTube 세션 제거
  static Future<void> clearDomainCookies(String domainHint) async {
    if (!supported || domainHint.trim().isEmpty) return;
    try {
      await _channel.invokeMethod<void>('clearDomainCookies', domainHint.trim());
    } on MissingPluginException {
      // no-op
    }
  }

  /// Safari·Chrome(인앱) 로그인 후 → WKWebView 쿠키 저장소로 복사 (best-effort)
  static Future<int> syncSafariCookiesToWebView() async {
    if (!supported) return 0;
    try {
      final n = await _channel.invokeMethod<int>('syncSafariCookiesToWebView');
      return n ?? 0;
    } on MissingPluginException {
      return 0;
    }
  }
}
