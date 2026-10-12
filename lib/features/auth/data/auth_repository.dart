import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/google_sign_in_config.dart';
import '../../../core/constants/env.dart';
import '../../../core/services/account_data_deletion_service.dart';
import '../../../core/services/isle_app_log_service.dart';
import 'models/user_profile.dart';

class AuthRepository {
  SupabaseClient get _client => Supabase.instance.client;

  static const oauthRedirect = 'isle://login-callback';

  Stream<User?> get authStream => Env.isSupabaseConfigured
      ? _client.auth.onAuthStateChange.map((e) => e.session?.user)
      : Stream<User?>.value(null);

  User? get currentUser => Env.isSupabaseConfigured ? _client.auth.currentUser : null;

  Future<void> signInWithEmail(String email, String password) {
    if (!Env.isSupabaseConfigured) {
      throw StateError('Supabase URL/Key를 env.dart에 설정하세요.');
    }
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(String email, String password) {
    if (!Env.isSupabaseConfigured) {
      throw StateError('Supabase URL/Key를 env.dart에 설정하세요.');
    }
    return _client.auth.signUp(email: email, password: password);
  }

  /// Google 계정 로그인 → Supabase 세션 (차단 채널 목록 클라우드 동기화용)
  Future<void> signInWithGoogle() async {
    if (!Env.isSupabaseConfigured) {
      throw StateError(
        'Google 로그인·차단 목록 저장에는 Supabase 백엔드가 필요합니다. '
        'env.dart에 URL/Key를 넣고, 대시보드에서 Google 제공자를 켜 주세요.',
      );
    }

    if (GoogleSignInConfig.isConfigured) {
      try {
        final gsi = GoogleSignInConfig.create();
        final account = await gsi.signIn();
        if (account == null) {
          throw StateError('Google 로그인이 취소되었습니다.');
        }
        final auth = await account.authentication;
        final idToken = auth.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw StateError('Google ID 토큰을 받지 못했습니다. Web Client ID를 Supabase에 등록했는지 확인하세요.');
        }
        await _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: auth.accessToken,
        );
        IsleAppLogService.log('Google sign-in (native) OK: ${account.email}');
        return;
      } catch (e, st) {
        IsleAppLogService.log(
          'Google native sign-in fallback to OAuth: $e',
          level: IsleLogLevel.warn,
          stack: st,
        );
      }
    }

    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : oauthRedirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    IsleAppLogService.log('Google OAuth flow started');
  }

  /// OAuth 딥링크 콜백 (`isle://login-callback?...`)
  Future<bool> handleAuthCallbackUri(Uri uri) async {
    if (!Env.isSupabaseConfigured) return false;
    if (!uri.scheme.startsWith('isle')) return false;
    try {
      await _client.auth.getSessionFromUrl(uri);
      IsleAppLogService.log('Auth callback session restored');
      return true;
    } catch (e, st) {
      IsleAppLogService.log('Auth callback failed: $e', level: IsleLogLevel.error, stack: st);
      return false;
    }
  }

  Future<void> signOut() async {
    if (!Env.isSupabaseConfigured) return;
    try {
      if (GoogleSignInConfig.isConfigured) {
        await GoogleSignInConfig.create().signOut();
      }
    } catch (_) {}
    await _client.auth.signOut();
    IsleAppLogService.log('Signed out — local Hive data kept on device');
  }

  /// 서버 프로필 삭제 + 로컬 민감 데이터 삭제 (인증 계정 완전 삭제는 이메일 요청).
  Future<void> deleteAccountAndLocalData() async {
    if (!Env.isSupabaseConfigured) {
      await AccountDataDeletionService.clearLocalSensitiveData();
      return;
    }
    await AccountDataDeletionService.deleteAccountAndLocalData(_client);
  }

  /// 로그인 사용자 — 서버 프로필·차단 동기화 데이터 삭제 후 로그아웃.
  /// auth.users 레코드 완전 삭제는 Supabase 관리자·이메일 요청으로 처리(Play 정책).
  Future<void> deleteRemoteAccountData() async {
    if (!Env.isSupabaseConfigured) {
      throw StateError('클라우드 연동이 설정되지 않았습니다.');
    }
    final user = currentUser;
    if (user == null) {
      throw StateError('로그인된 계정이 없습니다.');
    }
    final userId = user.id;
    await _client.from('blocked_channels').delete().eq('user_id', userId);
    await _client.from('profiles').delete().eq('id', userId);
    await signOut();
    IsleAppLogService.log('Remote account data deleted for $userId');
  }

  Future<UserProfile?> getProfile(String userId) async {
    if (!Env.isSupabaseConfigured) return null;
    final res = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    return res == null ? null : UserProfile.fromJson(res);
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    if (!Env.isSupabaseConfigured) {
      throw StateError('Supabase URL/Key를 env.dart에 설정하세요.');
    }
    final res = await _client.from('profiles').update(profile.toJson()).eq('id', profile.id).select().single();
    return UserProfile.fromJson(res);
  }

  Future<bool> isNewUser(String userId) async {
    if (!Env.isSupabaseConfigured) return true;
    final res = await _client.from('shelves').select('id').eq('user_id', userId).limit(1);
    return (res as List).isEmpty;
  }
}
