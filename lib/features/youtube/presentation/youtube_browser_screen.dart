import 'package:flutter/material.dart';

import '../../../core/explorer/explorer_site.dart';
import '../../explorer/presentation/web_explorer_screen.dart';
import 'widgets/youtube_browser_qa_host.dart';

/// 유튜브 전용 진입 — [WebExplorerScreen] 전체 화면 다크 크롬
class YoutubeBrowserScreen extends StatelessWidget {
  const YoutubeBrowserScreen({
    super.key,
    this.autoLogin = false,
    this.initialUrl,
    this.qaMode = false,
  });

  final bool autoLogin;
  final String? initialUrl;
  final bool qaMode;

  @override
  Widget build(BuildContext context) {
    final explorer = WebExplorerScreen(
      site: ExplorerSite.youtube,
      autoLogin: autoLogin,
      initialUrl: initialUrl,
    );
    if (!qaMode) return explorer;
    return YoutubeBrowserQaHost(child: explorer);
  }
}
