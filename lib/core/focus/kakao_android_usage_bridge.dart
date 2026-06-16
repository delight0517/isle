import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../services/isle_app_log_service.dart';
import 'kakao_shorts_addiction_store.dart';

/// Android 접근성 — `com.kakao.talk` 포그라운드 시 세션 자동 기록
class KakaoAndroidUsageBridge {
  KakaoAndroidUsageBridge._();

  static const _channel = EventChannel('com.isle.app/kakao_usage');
  static StreamSubscription<dynamic>? _sub;
  static bool _listening = false;

  static Future<void> ensureListening() async {
    if (!Platform.isAndroid || _listening) return;
    await KakaoShortsAddictionStore.ensureOpen();
    _sub = _channel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object e) {
        IsleAppLogService.log('KakaoAndroidUsageBridge error: $e', level: IsleLogLevel.warn);
      },
    );
    _listening = true;
    IsleAppLogService.log('KakaoAndroidUsageBridge listening');
  }

  static Future<void> _onEvent(dynamic raw) async {
    final event = raw?.toString() ?? '';
    if (event == 'started') {
      final started = await KakaoShortsAddictionStore.startAndroidSession();
      if (started != null) {
        IsleAppLogService.log('Kakao auto session started');
      }
      return;
    }
    if (event == 'ended') {
      final closed = await KakaoShortsAddictionStore.endAndroidSession();
      if (closed != null) {
        IsleAppLogService.log(
          'Kakao auto session ended (${closed.durationSeconds()}s)',
        );
      }
    }
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _listening = false;
  }
}
