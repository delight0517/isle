/// YouTube WebView — Google 로그인·2FA·동의 등 인증 흐름 URL
class GoogleAuthPathPolicy {
  GoogleAuthPathPolicy._();

  static const _authHosts = <String>[
    'accounts.google.com',
    'accounts.google.co.kr',
    'myaccount.google.com',
  ];

  static const _authPathHints = <String>[
    '/signin',
    '/servicelogin',
    '/challenge',
    '/oauth',
    '/consent',
    '/interstitials',
    '/speedbump',
  ];

  /// 로그인·2FA·패스키·동의 — Isle 스크립트·로딩 오버레이·한도 UI를 잠시 멈춤
  static bool isAuthFlowUrl(String url) {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    for (final h in _authHosts) {
      if (host == h || host.endsWith('.$h')) return true;
    }

    if (!host.contains('google')) return false;

    for (final hint in _authPathHints) {
      if (path.contains(hint)) return true;
    }
    if (url.toLowerCase().contains('servicelogin')) return true;
    return false;
  }
}
