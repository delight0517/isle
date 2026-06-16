import 'package:url_launcher/url_launcher.dart';

import 'instagram_web_config.dart';

/// Instagram 로그인 — Safari 인앱 브라우저(자동완성·2FA) 후 WebView 세션 공유
class InstagramAuthService {
  InstagramAuthService._();

  static Future<bool> openLoginInSafari() async {
    final uri = Uri.parse(InstagramWebConfig.loginUrl);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }
}
