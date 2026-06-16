import '../explorer/safari_web_config.dart';
import '../services/isle_user_defaults.dart';
import 'adult_domain_catalog.dart';

/// 안전 모드 — 성인 URL·검색 엔진 SafeSearch·유튜브 보조 키워드
class ContentSafetyGuard {
  ContentSafetyGuard._();

  static bool get enabled => IsleUserDefaults.contentSafetyEnabled;

  /// 유튜브 차단 스크립트에 합쳐질 기본 키워드 (사용자 키워드와 별도)
  static const builtInYoutubeKeywords = <String>[
    'pornhub',
    'xvideos',
    'xnxx',
    'xhamster',
    'hentai',
    'porno',
    'nsfw',
    'onlyfans',
    'nhentai',
    'missav',
  ];

  static ContentSafetyHit? matchUrl(String url) {
    if (!enabled) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    if (AdultDomainCatalog.hostMatches(uri.host)) {
      return const ContentSafetyHit(
        kind: ContentSafetyKind.adultDomain,
        label: '성인 사이트',
      );
    }
    return null;
  }

  /// 구글·Bing·DuckDuckGo 검색에 SafeSearch 파라미터 강제
  static String sanitizeUrl(String url) {
    if (!enabled) return url;
    return _bingSafeRewrite(url) ??
        SafariWebConfig.safeSearchRewrite(url) ??
        _duckDuckGoSafeRewrite(url) ??
        url;
  }

  static String? _bingSafeRewrite(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (!host.contains('bing.com')) return null;
    if (!uri.path.startsWith('/search')) return null;
    if (uri.queryParameters['adlt'] == 'strict') return null;
    final qp = Map<String, String>.from(uri.queryParameters)..['adlt'] = 'strict';
    return uri.replace(queryParameters: qp).toString();
  }

  static String? _duckDuckGoSafeRewrite(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (!host.contains('duckduckgo.com')) return null;
    if (uri.queryParameters['kp'] == '1' || uri.queryParameters['kp'] == '2') {
      return null;
    }
    final qp = Map<String, String>.from(uri.queryParameters)..['kp'] = '1';
    return uri.replace(queryParameters: qp).toString();
  }

  /// iOS Safari Content Blocker / Android VPN에 병합할 도메인
  static List<String> exportBlockDomains() {
    if (!enabled) return const [];
    return List<String>.from(AdultDomainCatalog.suffixes);
  }
}

enum ContentSafetyKind { adultDomain }

class ContentSafetyHit {
  const ContentSafetyHit({required this.kind, required this.label});

  final ContentSafetyKind kind;
  final String label;

  String get snackMessage => '안전 모드: $label 접근이 차단됐어요';
}
