import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/block_schedule/url_rules/host_expansion.dart';
import 'package:isle/core/block_schedule/url_rules/schedule_rule_kind.dart';
import 'package:isle/core/block_schedule/url_rules/url_rule_detector.dart';

void main() {
  group('UrlRuleDetector', () {
    test('reddit URL → host', () {
      final d = UrlRuleDetector.detect('https://reddit.com/r/gaming');
      expect(d.kind, ScheduleRuleKind.host);
      expect(d.pattern, 'reddit.com');
    });

    test('mingky01.live → urlContains + secondaryHost', () {
      final d = UrlRuleDetector.detect('https://mingky01.live/movie/e5f77');
      expect(d.kind, ScheduleRuleKind.urlContains);
      expect(d.pattern, 'mingky');
      expect(d.secondaryHost, 'mingky01.live');
    });

    test('포함:mingky → urlContains', () {
      final d = UrlRuleDetector.detect('포함:mingky');
      expect(d.kind, ScheduleRuleKind.urlContains);
      expect(d.pattern, 'mingky');
    });

    test('starcraft2 → keyword (no numeric evasion)', () {
      final d = UrlRuleDetector.detect('starcraft2');
      expect(d.kind, ScheduleRuleKind.keyword);
      expect(d.pattern, 'starcraft2');
    });

    test('youtube watch → videoUrl', () {
      final d = UrlRuleDetector.detect('https://youtube.com/watch?v=dQw4w9WgXcQ');
      expect(d.kind, ScheduleRuleKind.videoUrl);
    });

    test('youtube.com whole site needs confirmation', () {
      final d = UrlRuleDetector.detect('youtube.com');
      expect(d.kind, ScheduleRuleKind.host);
      expect(UrlRuleDetector.needsWholeSiteConfirmation(d), isTrue);
    });
  });

  group('HostExpansion', () {
    test('expandHost includes www and m', () {
      final expanded = HostExpansion.expandHost('example.com');
      expect(expanded, contains('example.com'));
      expect(expanded, contains('www.example.com'));
      expect(expanded, contains('m.example.com'));
    });

    test('canonicalHost strips www', () {
      expect(
        HostExpansion.canonicalHost('https://www.pornhub.com/video/x'),
        'pornhub.com',
      );
    });
  });
}
