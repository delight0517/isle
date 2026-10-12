import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/isle_external_launch_guard.dart';
import 'instagram_safari_launch_guard.dart';
import 'instagram_web_config.dart';

/// Instagram 로그인 — Safari 인앱 브라우저(자동완성·2FA) · 차단·한도 중 우회 방지
class InstagramAuthService {
  InstagramAuthService._();

  static Future<bool> openLoginInSafari({BuildContext? context}) async {
    final deny = InstagramSafariLaunchGuard.denyBrowsingEscape();
    if (deny != null) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$deny · Safari 로그인은 사용할 수 없어요')),
        );
      }
      return false;
    }
    return IsleExternalLaunchGuard.launchAllowed(
      InstagramWebConfig.loginUrl,
      mode: LaunchMode.inAppBrowserView,
      context: context,
    );
  }
}
