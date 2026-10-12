import 'app_locale_policy.dart';

/// Request the app's display language without rewriting posts or messages.
class WebLocalePolicy {
  WebLocalePolicy._();

  static const _hosts = {
    'instagram.com',
    'www.instagram.com',
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
  };

  static bool supports(Uri uri) {
    if (uri.scheme != 'https' || !_hosts.contains(uri.host.toLowerCase())) {
      return false;
    }
    final path = uri.path.toLowerCase();
    return !['/accounts', '/challenge', '/consent', '/signin', '/logout']
        .any((prefix) => path == prefix || path.startsWith('$prefix/'));
  }

  static Uri initialUri(String url, String? code) {
    final uri = Uri.parse(url);
    if (!supports(uri)) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParametersAll,
      'hl': [AppLocalePolicy.normalize(code)],
    });
  }

  static Map<String, String> headers(Uri uri, String? code) => supports(uri)
      ? {'Accept-Language': AppLocalePolicy.normalize(code)}
      : const {};
}
