import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/env.dart';
import '../platform/isle_web_session_persistence_service.dart';
import '../platform/web_session_cookie_bridge.dart';
import 'isle_app_log_service.dart';
import 'isle_user_defaults.dart';

/// Play 정책 — 로컬·서버 데이터 삭제 경로.
class AccountDataDeletionService {
  AccountDataDeletionService._();

  /// 로그인 계정 + 기기 데이터 삭제 (Supabase 프로필 best-effort).
  static Future<void> deleteAccountAndLocalData(SupabaseClient? client) async {
    final userId = client?.auth.currentUser?.id;
    if (Env.isSupabaseConfigured && client != null && userId != null) {
      try {
        await client.from('profiles').delete().eq('id', userId);
      } catch (e, st) {
        IsleAppLogService.log('Profile delete: $e', level: IsleLogLevel.warn, stack: st);
      }
      try {
        await client.auth.signOut();
      } catch (_) {}
    }
    await clearLocalSensitiveData();
    IsleAppLogService.log('Account/local data deletion completed');
  }

  /// WebView 세션·쿠키·민감 플래그만 삭제 (계정 유지).
  static Future<void> clearLocalSensitiveData() async {
    await IsleWebSessionPersistenceService.clearStored();
    await IsleUserDefaults.setYoutubeWebLoginRemembered(false);
    await IsleUserDefaults.setInstagramLoginRemembered(false);
    try {
      if (WebSessionCookieBridge.supported) {
        await WebSessionCookieBridge.importCookies(const []);
      }
    } catch (_) {}
    try {
      const storage = FlutterSecureStorage();
      await storage.deleteAll();
    } catch (e, st) {
      IsleAppLogService.log('Secure storage clear: $e', level: IsleLogLevel.warn, stack: st);
    }
    IsleAppLogService.log('Local sensitive data cleared');
  }

  /// 전체 로컬 Hive 캐시·설정 초기화 (게스트 포함).
  static Future<void> wipeLocalHiveCaches() async {
    for (final name in [
      'isle_cache',
      'isle_feed_ingest',
      'isle_blocked_channels',
      'isle_content_filters',
      'isle_engagement',
    ]) {
      try {
        if (Hive.isBoxOpen(name)) {
          await Hive.box(name).clear();
        }
      } catch (e, st) {
        IsleAppLogService.log('Hive clear $name: $e', level: IsleLogLevel.warn, stack: st);
      }
    }
    await clearLocalSensitiveData();
  }
}
