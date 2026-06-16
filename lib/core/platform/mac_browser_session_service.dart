import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../services/isle_app_log_service.dart';

/// macOS — Safari·Chrome 등 브라우저 전면 시간 (5초 tick, Isle 실행 중)
class MacBrowserSessionService {
  MacBrowserSessionService._();

  static const _channel = MethodChannel('com.isle.app/mac_browser');

  static bool get isSupported => Platform.isMacOS;

  static Future<bool> startMonitoring() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('startMonitoring') == true;
    } catch (e, st) {
      IsleAppLogService.log('mac_browser start: $e', level: IsleLogLevel.error, stack: st);
      return false;
    }
  }

  static Future<void> stopMonitoring() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('stopMonitoring');
    } catch (_) {}
  }

  static Future<int> browserMinutesToday() async {
    if (!isSupported) return 0;
    try {
      return await _channel.invokeMethod<int>('browserMinutesToday') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<String?> frontBrowserBundleId() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('frontBrowserBundleId');
    } catch (_) {
      return null;
    }
  }
}
