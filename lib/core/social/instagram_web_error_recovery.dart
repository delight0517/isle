import 'package:webview_flutter/webview_flutter.dart';

import '../platform/isle_web_session_persistence_service.dart';
import '../platform/web_session_cookie_bridge.dart';
import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import 'instagram_web_config.dart';

/// Instagram WebView 「Unexpected error happened」— 만료 세션·쿠키 꼬임 복구
class InstagramWebErrorRecovery {
  InstagramWebErrorRecovery._();

  static const _probeJs = '''
(function() {
  try {
    var t = (document.body && document.body.innerText || '').toLowerCase();
    if (t.indexOf('unexpected error') >= 0) return 'unexpected';
    if (t.indexOf('something went wrong') >= 0) return 'generic';
    if (t.indexOf('오류가 발생') >= 0) return 'generic';
    if (t.indexOf('please wait a few minutes') >= 0) return 'rate';
  } catch (e) {}
  return '';
})()
''';

  static DateTime? _lastAutoRecoverAt;
  static const _recoverCooldown = Duration(minutes: 2);

  /// true — 세션 초기화 후 로그인 URL로 이동함
  static Future<bool> probeAndRecoverIfNeeded(WebViewController controller) async {
    if (!WebSessionCookieBridge.supported) return false;
    try {
      final raw = await controller.runJavaScriptReturningResult(_probeJs);
      final kind = _unwrapJsString(raw).trim().toLowerCase();
      if (kind.isEmpty) return false;

      final now = DateTime.now();
      if (_lastAutoRecoverAt != null &&
          now.difference(_lastAutoRecoverAt!) < _recoverCooldown) {
        return false;
      }
      _lastAutoRecoverAt = now;

      IsleAppLogService.log(
        'Instagram error page ($kind) — clearing session',
        level: IsleLogLevel.warn,
      );
      await _resetSession();
      await controller.loadRequest(Uri.parse(InstagramWebConfig.loginUrl));
      return true;
    } catch (e, st) {
      IsleAppLogService.log(
        'Instagram error probe failed: $e',
        level: IsleLogLevel.debug,
        stack: st,
      );
      return false;
    }
  }

  static Future<void> resetSessionManual() => _resetSession();

  static Future<void> _resetSession() async {
    await IsleWebSessionPersistenceService.clearStored();
    await IsleUserDefaults.setInstagramLoginRemembered(false);
    await WebSessionCookieBridge.clearDomainCookies('instagram');
  }

  static String _unwrapJsString(Object? raw) {
    if (raw == null) return '';
    var s = raw.toString();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1);
    }
    return s.replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
  }
}
