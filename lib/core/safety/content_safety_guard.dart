import '../explorer/safari_web_config.dart';
import 'adult_protection_service.dart';

/// 안전 모드 — [AdultProtectionService] 단일 출처 위임
class ContentSafetyGuard {
  ContentSafetyGuard._();

  static bool get enabled => AdultProtectionService.basicLayerEnabled;

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

  /// 구글 검색·이미지 차단에 사용할 성인 검색 키워드 내장 목록.
  /// 텍스트 결과 카드 + 이미지 그리드 양쪽에 적용된다.
  static const builtInAdultSearchKeywords = <String>[
    // 성인 잡지 / 브랜드
    'maxim', 'playboy', 'penthouse', 'hustler',
    // 명시적 성인 용어
    'nude', 'naked', 'nsfw', 'porn', 'pornographic', 'xxx',
    'hentai', 'erotic', 'lewd', 'risque',
    // 성인 플랫폼
    'onlyfans', 'fansly', 'chaturbate', 'livejasmin',
    // 반-성인 패션 검색어 (모델 조합)
    'lingerie model', 'bikini model', 'swimsuit model',
    // 성인 은어/속어 (한글)
    '거유', '초거유', '젖꼭지', '후방 주의', '골반', '참 젖', '젖',
    'y존', '노콘', '은꼴', '제로투', 'bj 벗방', '가슴골', '여자 가슴',
    '여자 엉덩이', '워터파크', '워터밤 여자', '젖꼭지 노출', '팬티 노출',
    '레이싱 모델', '글래머', '베이글녀', '빽보', '뷰지털', '비키니', '몸매',
    'sexy', '보털', '트월킹',
    // 2026-07-14 추가 — 사용자 제보 성인 은어(춤/몸매 묘사 밈 포함).
    '찌찌뽕', '꿀벅지', '여자 허벅지 둘레 60cm', '파송송', '파송무', '망치춤', '삐끼삐끼',
    '플러스 사이즈 모델', '돌격형 젖꼭지',
    // 2026-07-14 추가(2차) — 사용자 재제보. "요가팬츠"·"차간단"·"간단녀"는
    // 제외했다: "요가팬츠"는 일반 운동복 검색과 겹쳐 너무 광범위하고,
    // "차간단"·"간단녀"는 표준 성인 은어로 확인이 안 돼(의도 불명) 오탐
    // 위험이 커서 뺐다. 확인되면 알려주면 추가한다.
    '자위', '자위행위', 'masterbate', 'masterbation', '질싸', '대딸', '오나홀', '애무',
    'pussy', 'big butt', 'big ass', 'camel toe', 'booty', '누드 모델', 'nude model',
    // 성인·도박 "주소모아"류 링크 허브 검색어 — 사이트 자체는 도메인이
    // 계속 바뀌어 호스트 차단만으론 못 따라잡지만, 검색으로 찾아 들어가는
    // 진입 경로(구글 SERP 카드)는 검색어 자체가 거의 안 바뀌어서 여기서
    // 막을 수 있다(2026-07-13, 사용자 제보 — "주소모아 검색해서 들어가는
    // 것도 막아달라").
    '주소모아', '주소모음', '링크모음', '최신주소', '우회주소', '주소가이드',
    // 2026-07-11(3차) 추가 — 사용자 재제보. "요가팬츠"·"차간단"·"간단녀"는
    // 위 07-14 코멘트에서 오탐 우려로 뺐었지만 사용자가 같은 목록에 다시
    // 포함해 재확인했으므로 이번엔 포함한다(사용자 명시적 확인 우선).
    'bikini', 'beach woman', 'beach girl', '도끼자국', '도끼녀', '겨드랑이',
    'bj춤', '화끈한', '섹시', '야짤', '검열해제', '후방주의', '성인게임', '소녀전선',
    '요가팬츠', '차간단', '간단녀',
  ];

  static ContentSafetyHit? matchUrl(String url) {
    if (!enabled) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    if (AdultProtectionService.hostMatches(uri.host)) {
      return const ContentSafetyHit(
        kind: ContentSafetyKind.adultDomain,
        label: '성인 콘텐츠',
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

  /// iOS Safari Content Blocker / Android VPN에 병합할 도메인 (기본 tier)
  static List<String> exportBlockDomains() => AdultProtectionService.exportBlockDomains();
}

enum ContentSafetyKind { adultDomain }

class ContentSafetyHit {
  const ContentSafetyHit({required this.kind, required this.label});

  final ContentSafetyKind kind;
  final String label;

  String get snackMessage => '안전 모드: $label 접근이 차단됐어요';
}
