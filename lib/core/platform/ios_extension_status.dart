import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Xcode에 임베드된 iOS appex 존재 여부 (빌드 후 PlugIns 폴더).
class IosExtensionStatus {
  IosExtensionStatus._();

  static const _channel = MethodChannel('com.isle.app/screen_time');

  static Future<IosExtensionStatusResult> load() async {
    if (!Platform.isIOS) {
      return const IosExtensionStatusResult(
        deviceActivityMonitor: false,
        safariContentBlocker: false,
      );
    }
    try {
      final raw = await _channel.invokeMethod<dynamic>('embeddedExtensionsStatus');
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        return IosExtensionStatusResult(
          deviceActivityMonitor: m['deviceActivityMonitor'] == true,
          safariContentBlocker: m['safariContentBlocker'] == true,
        );
      }
    } catch (_) {}
    return const IosExtensionStatusResult(
      deviceActivityMonitor: false,
      safariContentBlocker: false,
    );
  }

  static Future<void> openSafariSettings() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('openSafariSettings');
    } catch (_) {}
  }
}

class IosExtensionStatusResult {
  const IosExtensionStatusResult({
    required this.deviceActivityMonitor,
    required this.safariContentBlocker,
  });

  final bool deviceActivityMonitor;
  final bool safariContentBlocker;

  bool get allEmbedded => deviceActivityMonitor && safariContentBlocker;
}
