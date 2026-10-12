import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/isle_app_log_service.dart';
import 'web_session_cookie_bridge.dart';

/// YouTube·Instagram WebView 로그인 쿠키 — Keychain/Keystore 미러 (재빌드·재설치 복원)
class IsleWebSessionPersistenceService {
  IsleWebSessionPersistenceService._();

  static const _storageKey = 'isle_web_session_cookies_v1';
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Timer? _saveDebounce;
  static bool _restoredThisLaunch = false;

  /// 부팅 직후·WebView 생성 전 호출
  static Future<void> restoreOnBootstrap() async {
    if (_restoredThisLaunch || !WebSessionCookieBridge.supported) return;
    _restoredThisLaunch = true;
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) return;
      final cookies = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (cookies.isEmpty) return;
      await WebSessionCookieBridge.importCookies(cookies);
      IsleAppLogService.log(
        'Web session cookies restored (${cookies.length})',
      );
    } catch (e, st) {
      IsleAppLogService.log(
        'Web session restore failed: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
    }
  }

  /// 로그인 감지·페이지 준비 후 디바운스 저장
  static void scheduleSave() {
    if (!WebSessionCookieBridge.supported) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 4), () {
      unawaited(saveNow());
    });
  }

  static Future<void> saveNow() async {
    if (!WebSessionCookieBridge.supported) return;
    try {
      final exported = await WebSessionCookieBridge.exportCookies();
      if (exported.isEmpty) return;
      if (!_looksLikeLoggedIn(exported)) return;
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(exported),
      );
      IsleAppLogService.log(
        'Web session cookies saved (${exported.length})',
      );
    } catch (e, st) {
      IsleAppLogService.log(
        'Web session save failed: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
    }
  }

  static bool _looksLikeLoggedIn(List<Map<String, dynamic>> cookies) {
    for (final c in cookies) {
      final name = (c['name'] as String? ?? '').toUpperCase();
      final domain = (c['domain'] as String? ?? '').toLowerCase();
      if (domain.contains('instagram') &&
          (name == 'SESSIONID' || name == 'DS_USER_ID')) {
        return true;
      }
      if ((domain.contains('youtube') || domain.contains('google')) &&
          (name == 'SID' ||
              name == 'HSID' ||
              name == 'SSID' ||
              name == 'APISID' ||
              name == 'SAPISID' ||
              name == 'LOGIN_INFO')) {
        return true;
      }
    }
    return false;
  }

  /// 명시적 로그아웃 시에만 호출 (일반 업데이트는 유지)
  static Future<void> clearStored() async {
    _saveDebounce?.cancel();
    await _storage.delete(key: _storageKey);
  }
}
