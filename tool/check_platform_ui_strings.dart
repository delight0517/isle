// ignore_for_file: avoid_print

import 'dart:io';

/// OS 전용 UI **문자열 리터럴**이 공유 UI에 새로 들어가면 경고.
///
/// 실행:
///   `dart run tool/check_platform_ui_strings.dart`        — 경고만 (exit 0)
///   `dart run tool/check_platform_ui_strings.dart --fail` — 위반 시 exit 1
void main(List<String> args) {
  final failOnViolation = args.contains('--fail');

  final root = Directory.current.path.endsWith('isle')
      ? Directory.current
      : Directory('isle');
  if (!root.existsSync()) {
    stderr.writeln('Run from repo root or isle/');
    exit(2);
  }

  /// 이미 OS 전용 화면·레거시 — 점진 이전 대상 (신규 위반은 다른 파일에서)
  const legacyAllowFiles = {
    'safari_youtube_os_block_screen.dart',
    'iphone_blocking_capabilities_screen.dart',
    'browser_youtube_tracking_screen.dart',
    'external_app_control_screen.dart',
    'safari_youtube_inbound_section.dart',
    'website_block_section.dart',
    'screen_time_guide_sheet.dart',
    'youtube_login_guide_screen.dart',
    'block_setup_steps.dart',
    'platform_usage_stats_screen.dart',
    'device_qa_screen.dart',
    'youtube_default_handler_screen.dart',
    'kakao_shorts_focus_section.dart',
  };

  const scanRoots = ['lib/features', 'lib/shared'];
  const forbiddenTerms = ['Safari', 'Screen Time', 'FamilyControls'];

  var violations = 0;

  for (final rel in scanRoots) {
    final dir = Directory('${root.path}/$rel');
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      final fileName = path.split('/').last;
      if (legacyAllowFiles.contains(fileName)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().startsWith('//')) continue;
        if (!RegExp(r"Text\(|title:|subtitle:|label:|content:|SnackBar\(")
            .hasMatch(line)) {
          continue;
        }
        if (line.contains('PlatformBlockCopy') ||
            line.contains('PlatformCopyResolver') ||
            line.contains('PlatformFeatureGate')) {
          continue;
        }

        final literalRe = RegExp("(?:'([^']*)'|\"([^\"]+)\")");
        final literals = literalRe
            .allMatches(line)
            .map((m) => m.group(1) ?? m.group(2) ?? '')
            .where((s) => s.isNotEmpty);

        for (final literal in literals) {
          for (final term in forbiddenTerms) {
            if (literal.contains(term)) {
              print('${path}:${i + 1}');
              print('  UI literal contains "$term"');
              print('  → use PlatformBlockCopy / PlatformCopyResolver');
              print('  $line');
              violations++;
            }
          }
        }
      }
    }
  }

  if (violations > 0) {
    print('\n$violations possible violation(s) (legacy screens excluded).');
    if (failOnViolation) exit(1);
  } else {
    print('check_platform_ui_strings: OK (non-legacy shared UI)');
  }
}
