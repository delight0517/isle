import '../block_schedule_store.dart';
import '../models/block_schedule.dart';
import '../schedule_enforcement_policy.dart';
import 'host_expansion.dart';
import 'schedule_rule.dart';
import 'schedule_rule_kind.dart';
import 'schedule_rule_store.dart';
import 'url_rule_detector.dart';

/// 활성 스케줄 규칙 → DNS·urlParts·키워드 (Blueprint §4)
class ScheduleRuleEnforcement {
  ScheduleRuleEnforcement._();

  static List<BlockSchedule> _shieldSchedulesNow([DateTime? at]) =>
      ScheduleEnforcementPolicy.shieldSchedulesNow(at);

  static List<ScheduleRule> activeRulesNow([DateTime? at]) {
    if (!BlockScheduleStore.masterEnabled) return [];
    final ids = _shieldSchedulesNow(at).map((s) => s.id).toSet();
    return ScheduleRuleStore.loadAll().where((r) => ids.contains(r.scheduleId)).toList();
  }

  static List<String> mergedExpandedHostsNow([DateTime? at]) {
    final set = <String>{};
    for (final s in _shieldSchedulesNow(at)) {
      set.addAll(s.domains.map((d) => d.toLowerCase().trim()));
    }
    for (final r in activeRulesNow(at)) {
      if (r.kind == ScheduleRuleKind.host || r.kind == ScheduleRuleKind.wildcard) {
        set.addAll(HostExpansion.expandHost(r.pattern));
      }
    }
    return set.where((d) => d.isNotEmpty).toList()..sort();
  }

  static List<String> mergedUrlPartsNow([DateTime? at]) {
    final set = <String>{};
    for (final r in activeRulesNow(at)) {
      if (r.kind == ScheduleRuleKind.urlContains) {
        set.add(r.pattern);
      }
      final stem = UrlRuleDetector.numericEvasionUrlPartForHostRule(r.pattern, r.kind);
      if (stem != null) set.add(stem);
    }
    return set.toList()..sort();
  }

  static List<String> activeKeywordsNow([DateTime? at]) {
    return activeRulesNow(at)
        .where((r) => r.kind == ScheduleRuleKind.keyword || r.kind == ScheduleRuleKind.genreKeyword)
        .map((r) => r.pattern)
        .toSet()
        .toList()
      ..sort();
  }

  static bool urlMatchesActiveRules(String? raw, [DateTime? at]) {
    if (raw == null || raw.trim().isEmpty) return false;
    var url = raw.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;

    final host = uri.host.toLowerCase();
    final addr = (host + uri.path).toLowerCase();

    for (final h in mergedExpandedHostsNow(at)) {
      if (HostExpansion.hostMatches(host, h)) return true;
    }

    for (final part in mergedUrlPartsNow(at)) {
      if (part.isEmpty) continue;
      if (addr.contains(part)) return true;
    }
    return false;
  }
}
