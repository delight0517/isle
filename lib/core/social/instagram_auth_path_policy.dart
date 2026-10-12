/// Instagram WebView — 로그인·2FA·동의 등 인증 흐름 URL
class InstagramAuthPathPolicy {
  InstagramAuthPathPolicy._();

  static const _prefixes = <String>[
    '/accounts',
    '/challenge',
    '/consent',
    '/auth',
    '/oauth',
    '/session',
  ];

  /// 로그인·패스키·2FA·동의 — DM 차단·스크립트 주입·한도 오버레이를 잠시 멈춤
  static bool isAuthFlowPath(String path) {
    final p = path.toLowerCase();
    if (p.isEmpty) return false;
    for (final prefix in _prefixes) {
      if (p.startsWith(prefix)) return true;
    }
    return false;
  }

  static bool isAuthFlowUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    return isAuthFlowPath(path);
  }
}
