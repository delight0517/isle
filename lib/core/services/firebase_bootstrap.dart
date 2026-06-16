import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

import 'isle_app_log_service.dart';

/// Android: `google-services.json` + Gradle 플러그인으로 초기화.
/// iOS는 `GoogleService-Info.plist` 추가 전까지 skip.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static FirebaseAnalytics? analytics;

  static Future<void> initializeIfSupported() async {
    if (!Platform.isAndroid) {
      IsleAppLogService.log('Firebase skip (Android only until iOS plist)');
      return;
    }
    await Firebase.initializeApp();
    analytics = FirebaseAnalytics.instance;
    await analytics!.logAppOpen();
    IsleAppLogService.log('Firebase initialized (Analytics ready)');
  }
}
