/// 안전 모드 — 성인 사이트 도메인 접미사 (Isle WebView·Safari 규칙)
class AdultDomainCatalog {
  AdultDomainCatalog._();

  /// 접미사 매칭 — `evil.pornhub.com` → `pornhub.com`
  static const suffixes = <String>[
    'pornhub.com',
    'xvideos.com',
    'xnxx.com',
    'xhamster.com',
    'redtube.com',
    'youporn.com',
    'spankbang.com',
    'eporner.com',
    'hqporner.com',
    'porntrex.com',
    'txxx.com',
    'jav.guru',
    'missav.com',
    'avgle.com',
    'chaturbate.com',
    'onlyfans.com',
    'fansly.com',
    'literotica.com',
    'rule34.xxx',
    'nhentai.net',
    'hanime.tv',
    'hentaihaven.xxx',
    'fakku.net',
    'brazzers.com',
    'bangbros.com',
    'realitykings.com',
    'adultfriendfinder.com',
    'cam4.com',
    'bongacams.com',
    'stripchat.com',
    'livejasmin.com',
  ];

  static bool hostMatches(String host) {
    final h = host.toLowerCase().trim();
    if (h.isEmpty) return false;
    for (final suffix in suffixes) {
      if (h == suffix || h.endsWith('.$suffix')) return true;
    }
    return false;
  }
}
