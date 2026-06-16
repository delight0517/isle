/// DNS host 정규화·서브도메인 확장 (Blueprint §3①)
class HostExpansion {
  HostExpansion._();

  static const commonSubdomains = [
    'www',
    'm',
    'mobile',
    'api',
    'cdn',
    'static',
    'img',
    'images',
    'media',
    'video',
    'mail',
    'web',
    'app',
    'secure',
  ];

  /// `https://www.pornhub.com/video/…` → `pornhub.com`
  static String? canonicalHost(String input) {
    var s = input.trim().toLowerCase();
    if (s.isEmpty) return null;
    s = s.replaceFirst(RegExp(r'^https?://'), '');
    s = s.split('/').first.split('?').first.split('#').first;
    if (s.contains(':')) s = s.split(':').first;
    if (s.startsWith('www.')) s = s.substring(4);
    if (!s.contains('.') || s.contains(' ') || s.length < 4) return null;
    return s;
  }

  static List<String> expandHost(String host) {
    final base = canonicalHost(host) ?? host.toLowerCase().trim();
    if (base.isEmpty) return [];
    final set = <String>{base, 'www.$base'};
    for (final sub in commonSubdomains) {
      if (sub == 'www') continue;
      set.add('$sub.$base');
    }
    return set.toList()..sort();
  }

  static bool hostMatches(String host, String domain) {
    final d = canonicalHost(domain) ?? domain.toLowerCase();
    final h = host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final base = d.replaceFirst(RegExp(r'^www\.'), '');
    return h == base || h.endsWith('.$base');
  }
}
