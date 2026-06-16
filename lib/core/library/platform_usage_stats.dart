import 'dart:io' show Platform;

import '../platform/mac_browser_session_service.dart';
import 'engagement_tracker.dart';

/// 인스타·유튜브·브런치 — 앱 내 체류 시간 집계 (EngagementTracker 기반)
class PlatformUsageStats {
  PlatformUsageStats._();

  static const platforms = ['youtube', 'instagram', 'brunch'];

  static const _labels = {
    'youtube': 'YouTube',
    'instagram': 'Instagram',
    'brunch': 'Brunch',
  };

  static String labelFor(String platform) => _labels[platform] ?? platform;

  static Future<Map<String, int>> secondsByPlatform() async {
    await EngagementTracker.ensureOpen();
    final screens = EngagementTracker.screenSecondsRaw();
    final out = {for (final p in platforms) p: 0};
    for (final e in screens.entries) {
      final id = e.key.toLowerCase();
      for (final p in platforms) {
        if (id.contains(p)) {
          out[p] = (out[p] ?? 0) + e.value;
        }
      }
    }
    return out;
  }

  /// macOS — Safari·Chrome 전면 시간 (네이티브 5초 tick)
  static Future<int> macBrowserSecondsToday() async {
    if (!Platform.isMacOS) return 0;
    final minutes = await MacBrowserSessionService.browserMinutesToday();
    return minutes * 60;
  }

  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0분';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '$h시간 $m분';
    if (m > 0) return '$m분';
    return '${seconds}초';
  }
}
