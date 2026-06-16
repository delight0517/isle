import 'google_search_keyword_block_script.dart';

/// Google/일반 웹 검색 결과에서 키워드 포함 카드를 숨기는 경량 스크립트.
class WebKeywordBlockScript {
  WebKeywordBlockScript._();

  static String build(List<String> blockedKeywords) =>
      GoogleSearchKeywordBlockScript.build(blockedKeywords);
}
