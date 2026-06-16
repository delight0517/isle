import 'schedule_rule_enforcement.dart';

class ScheduleWebBlockHit {
  const ScheduleWebBlockHit({
    required this.label,
    this.matchedPart,
  });

  final String label;
  final String? matchedPart;

  String get snackMessage => '스케줄 차단: $label';
}

/// 스케줄 활성 시간 — host·urlContains 4겹 레이어 (Blueprint §3)
class ScheduleWebBlockGuard {
  ScheduleWebBlockGuard._();

  static ScheduleWebBlockHit? matchUrl(String? raw) {
    if (!ScheduleRuleEnforcement.urlMatchesActiveRules(raw)) return null;
    final parts = ScheduleRuleEnforcement.mergedUrlPartsNow();
    var url = raw!.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return const ScheduleWebBlockHit(label: '이 사이트는 지금 차단되어 있습니다');
    }
    final addr = (uri.host + uri.path).toLowerCase();
    for (final p in parts) {
      if (addr.contains(p)) {
        return ScheduleWebBlockHit(
          label: '주소에 \'$p\' 가 포함된 사이트',
          matchedPart: p,
        );
      }
    }
    return ScheduleWebBlockHit(label: uri.host);
  }
}
