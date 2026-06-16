import 'dart:async';

import '../platform/ios_rules_export_service.dart';

/// 차단 채널·영상·키워드 변경 → Safari rules seed 갱신
class YoutubeBlockRulesSync {
  YoutubeBlockRulesSync._();

  static Future<void>? _pending;

  static void scheduleExport() {
    _pending ??= Future<void>.delayed(const Duration(milliseconds: 400), () async {
      _pending = null;
      await IosRulesExportService.exportNow();
    });
  }
}
