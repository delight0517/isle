import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/localization/schedule_strings.dart';

/// 로케일 테이블 간 키 누락 방지 — 한 언어에만 있는 키는 다른 언어에서 raw key로 새어나온다.
/// (실제로 target_explainer_* 등 5개 키가 _ko에만 있어 영어 화면에 키가 그대로 노출됐던 버그)
void main() {
  const langs = ['ko', 'en', 'ja', 'zh', 'he'];

  // 스케줄 허브·편집 화면(재설계 후)이 참조하는 핵심 키 — 모든 언어에서 실제 번역으로
  // 해석돼야 한다. `check_footer`는 의도적으로 빈 문자열일 수 있어 제외.
  const requiredKeys = [
    'schedule_name_hint',
    'target_explainer_body',
    'target_domain_youtube_only',
    'target_name_mismatch',
    'step1_title',
    'step2_title',
    'step3_title',
    'step4_title',
    'schedule_name',
    'schedule_enabled',
    'hub_help_body',
    'hub_status_idle',
    'schedule_settings',
    'edit_help_body',
    'check_step1',
    'check_step1_need',
    'check_step1_ok',
    'check_step2',
    'check_step2_need',
    'check_step2_ok',
    'check_step2_optional',
  ];

  for (final lang in langs) {
    final s = ScheduleStrings(lang);
    for (final key in requiredKeys) {
      test('[$lang] resolves "$key" to a real string, not the raw key', () {
        final v = s.t(key);
        expect(v, isNot(equals(key)),
            reason: '$lang 테이블에 "$key"가 없어 raw key가 UI에 노출됩니다');
        expect(v.trim(), isNotEmpty);
      });
    }
  }
}
