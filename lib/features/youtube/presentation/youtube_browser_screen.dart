import 'package:flutter/material.dart';

import '../../../core/explorer/explorer_site.dart';
import '../../explorer/presentation/web_explorer_screen.dart';

/// 유튜브 전용 진입 — [WebExplorerScreen] 전체 화면 다크 크롬
class YoutubeBrowserScreen extends StatelessWidget {
  const YoutubeBrowserScreen({
    super.key,
    this.autoLogin = false,
    this.initialUrl,
    this.loginOnly = false,
  });

  final bool autoLogin;
  final String? initialUrl;
  final bool loginOnly;

  @override
  Widget build(BuildContext context) {
    return WebExplorerScreen(
      site: ExplorerSite.youtube,
      autoLogin: autoLogin,
      initialUrl: initialUrl,
      loginOnly: loginOnly,
    );
  }
}
