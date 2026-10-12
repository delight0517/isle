import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../safe_browser/web_content_rule_compiler.dart';
import '../services/isle_app_log_service.dart';
import 'ios_rules_export_service.dart';

/// iOS WKContentRuleList — Safari CB와 동일 JSON 컴파일 (인앱 WebView OS 레벨 차단)
class IosWebContentRuleService {
  IosWebContentRuleService._();

  static const _channel = MethodChannel('com.isle.app/web_content_rules');

  /// rules export 후 호출 — App Group `content_blocker_v1.json` → WK compile
  static Future<bool> compileAfterExport() async {
    if (!Platform.isIOS) return false;
    try {
      await _channel.invokeMethod<void>('compileFromAppGroup');
      return true;
    } catch (e, st) {
      IsleAppLogService.log(
        'IosWebContentRuleService.compile failed: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
      return false;
    }
  }

  /// 도메인 수집 → export → WK compile (부팅·규칙 변경 시)
  static Future<void> syncAll() async {
    if (!Platform.isIOS) return;
    await IosRulesExportService.exportNow();
    await compileAfterExport();
  }

  static Future<int> domainCount() async {
    final domains = await WebContentRuleCompiler.collectBlockDomains();
    return domains.length;
  }
}
