/// Instagram WebView — 모바일 Safari UA (로그인·DM 호환)
class InstagramWebConfig {
  InstagramWebConfig._();

  static const mobileSafariUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';

  static const dmInboxUrl = 'https://www.instagram.com/direct/inbox/';
  static const loginUrl = 'https://www.instagram.com/accounts/login/';
  static const homeUrl = 'https://www.instagram.com/';

  static String dmBrowserRoute({bool dmOnly = true}) =>
      '/explore/browser?site=instagram&dm=${dmOnly ? '1' : '0'}&url=${Uri.encodeComponent(dmOnly ? dmInboxUrl : homeUrl)}';
}
