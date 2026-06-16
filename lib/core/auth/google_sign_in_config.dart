import 'dart:io' show Platform;

import 'package:google_sign_in/google_sign_in.dart';

import '../constants/env.dart';

/// iOS / Android / Supabase용 GoogleSignIn 단일 설정
class GoogleSignInConfig {
  GoogleSignInConfig._();

  static bool get isConfigured => Env.isGoogleSignInConfigured;

  static GoogleSignIn create({List<String> scopes = const ['email', 'profile']}) {
    return GoogleSignIn(
      scopes: scopes,
      clientId: Platform.isIOS && Env.googleIosClientId.isNotEmpty
          ? Env.googleIosClientId
          : null,
      serverClientId: _serverClientId,
    );
  }

  static String? get _serverClientId {
    final web = Env.googleWebClientId.trim();
    if (web.isNotEmpty && !web.contains('YOUR')) return web;
    return null;
  }

  static String get platformSetupHint {
    if (Platform.isAndroid) {
      return 'Android: Google Cloud에 Android OAuth 클라이언트(패키지 com.isle.app + SHA-1)와 '
          'Supabase용 Web 클라이언트 ID를 env.dart → googleWebClientId에 넣으세요.';
    }
    if (Platform.isIOS) {
      return 'iOS: env.dart → googleIosClientId + Info.plist URL scheme.';
    }
    return 'env.dart에 Google OAuth 클라이언트 ID를 설정하세요.';
  }
}
