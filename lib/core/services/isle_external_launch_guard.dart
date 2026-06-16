import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../guard/isle_content_block_guard.dart';

/// 앱이 띄우는 Safari·Chrome 열기 — 차단 목록·한도 우회 방지
class IsleExternalLaunchGuard {
  IsleExternalLaunchGuard._();

  static String? deny(String url) => IsleContentBlockGuard.denyUrl(url);

  static Future<bool> launch(
    BuildContext context,
    String url, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    final deny = denyLaunch(url);
    if (deny != null) {
      _showDeny(context, deny);
      return false;
    }
    return launchAllowed(url, mode: mode);
  }

  static String? denyLaunch(String url) => deny(url);

  static Future<bool> launchAllowed(
    String url, {
    LaunchMode mode = LaunchMode.externalApplication,
    BuildContext? context,
  }) async {
    final deny = denyLaunch(url);
    if (deny != null) {
      if (context != null && context.mounted) _showDeny(context, deny);
      return false;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) return false;
    await launchUrl(uri, mode: mode);
    return true;
  }

  static void _showDeny(BuildContext context, String deny) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$deny (외부 브라우저)')),
    );
  }
}
