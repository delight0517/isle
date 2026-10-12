import '../block_schedule/block_schedule_store.dart';
import '../block_schedule/url_rules/schedule_rule_enforcement.dart';
import '../intervention/always_on_url_pattern_store.dart';
import '../intervention/website_block_store.dart';
import '../safety/content_safety_guard.dart';

/// Safari Content Blocker JSON ↔ WKContentRuleList 공용 규칙 생성
class WebContentRuleCompiler {
  WebContentRuleCompiler._();

  static Future<List<String>> collectBlockDomains() async {
    final domains = <String>{};
    domains.addAll(ScheduleRuleEnforcement.mergedExpandedHostsNow());
    for (final s in BlockScheduleStore.loadAll()) {
      if (!s.enabled) continue;
      domains.addAll(s.domains.map((d) => d.toLowerCase().trim()));
    }
    await WebsiteBlockStore.ensureOpen();
    domains.addAll(WebsiteBlockStore.loadDomains().map((d) => d.toLowerCase().trim()));
    domains.addAll(ContentSafetyGuard.exportBlockDomains());
    return domains.where((d) => d.isNotEmpty).toList()..sort();
  }

  /// [AlwaysOnUrlPatternStore]에 저장된 어간("mingky" 등) — 특정 스케줄에
  /// 묶이지 않고 24시간 항상 적용된다.
  static Future<List<String>> collectAlwaysOnStems() async {
    await AlwaysOnUrlPatternStore.ensureOpen();
    return AlwaysOnUrlPatternStore.loadStems();
  }

  /// Safari CB · WKContentRuleList 동일 포맷
  static List<Map<String, dynamic>> rulesFromDomains(List<String> domains) {
    if (domains.isEmpty) return const [];
    return [
      for (final d in domains)
        {
          'action': {'type': 'block'},
          'trigger': {
            'url-filter': '.*',
            'if-domain': ['*${d.replaceAll(RegExp(r'^www\.'), '')}'],
          },
        },
    ];
  }

  /// 어간+숫자 우회 미러 사이트용 — `if-domain`은 정확한 도메인만 받으므로
  /// 여기서는 순수 정규식 `url-filter`를 직접 써서 mingky01.live·
  /// mingky2.net처럼 아직 안 나온 번호·TLD 변형까지 한 규칙으로 막는다
  /// (Safari Content Blocker/WKContentRuleList 둘 다 ICU 정규식 `url-filter`를
  /// `if-domain` 없이 단독으로 지원 — 네이티브 쪽은 이 JSON을 그대로
  /// 파일에 쓰기만 하므로 추가 네이티브 변경 없이 동작한다).
  static List<Map<String, dynamic>> rulesFromStems(List<String> stems) {
    if (stems.isEmpty) return const [];
    return [
      for (final s in stems)
        if (s.isNotEmpty)
          {
            'action': {'type': 'block'},
            'trigger': {
              'url-filter': '${RegExp.escape(s)}[0-9]+\\.',
              'url-filter-is-case-sensitive': false,
            },
          },
    ];
  }
}
