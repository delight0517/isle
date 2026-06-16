import '../../utils/url_parser.dart';
import 'host_expansion.dart';
import 'schedule_rule_kind.dart';

class DetectedScheduleRule {
  const DetectedScheduleRule({
    required this.kind,
    required this.pattern,
    this.hint,
    this.secondaryHost,
    this.variationStem,
  });

  final ScheduleRuleKind kind;
  final String pattern;
  final String? hint;
  /// 숫자 우회 시 함께 추가할 정확 host (Blueprint §3②)
  final String? secondaryHost;
  /// 변형 제안 배너용 (Blueprint §3④)
  final String? variationStem;
}

/// 붙여넣기 한 줄 → 규칙 분류 (Blueprint §2.1)
class UrlRuleDetector {
  UrlRuleDetector._();

  static DetectedScheduleRule detect(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const DetectedScheduleRule(kind: ScheduleRuleKind.keyword, pattern: '');
    }

    // 1 genre:
    final genre = _parseGenre(trimmed);
    if (genre != null) {
      return DetectedScheduleRule(
        kind: ScheduleRuleKind.genreKeyword,
        pattern: genre,
        hint: '장르 키워드로 피드·검색에서 숨깁니다',
      );
    }

    // 2–6 YouTube
    final yt = _detectYoutube(trimmed);
    if (yt != null) return yt;

    // 7 wildcard *.example.com
    if (trimmed.startsWith('*.')) {
      final host = HostExpansion.canonicalHost(trimmed.substring(2));
      if (host != null) {
        return DetectedScheduleRule(
          kind: ScheduleRuleKind.wildcard,
          pattern: host,
          hint: '와일드카드 · $host 및 서브도메인',
        );
      }
    }

    // 8 urlContains
    final contains = _parseUrlContains(trimmed);
    if (contains != null) {
      return DetectedScheduleRule(
        kind: ScheduleRuleKind.urlContains,
        pattern: contains,
        hint: '주소에 \'$contains\' 가 들어가면 모두 막습니다',
      );
    }

    // 9 numeric evasion
    final numeric = _numericEvasionContext(trimmed);
    if (numeric != null) return numeric;

    // 10 keyword (not a domain)
    if (!_looksLikeDomain(trimmed)) {
      final kw = trimmed.toLowerCase();
      return DetectedScheduleRule(
        kind: ScheduleRuleKind.keyword,
        pattern: kw,
        hint: '키워드 · 피드·검색 숨김',
        variationStem: _variationStemForKeyword(kw),
      );
    }

    // 11 host fallback
    final host = HostExpansion.canonicalHost(trimmed) ?? trimmed.toLowerCase();
    return DetectedScheduleRule(
      kind: ScheduleRuleKind.host,
      pattern: host,
      hint: '사이트 전체 · DNS + Safari',
      variationStem: _variationStemForHost(host),
    );
  }

  static String? detectHint(String raw) => detect(raw).hint;

  static String? variationStem(String raw) {
    final d = detect(raw);
    if (d.kind == ScheduleRuleKind.urlContains) return null;
    if (d.secondaryHost != null) return null;
    return d.variationStem;
  }

  static bool needsWholeSiteConfirmation(DetectedScheduleRule d) {
    if (d.kind != ScheduleRuleKind.host) return false;
    const whole = {'youtube.com', 'youtu.be', 'm.youtube.com', 'www.youtube.com'};
    return whole.contains(d.pattern);
  }

  /// host 규칙에서 숫자 어간 → urlParts (Blueprint UsageIngestServer)
  static String? numericEvasionUrlPartForHostRule(String pattern, ScheduleRuleKind kind) {
    if (kind != ScheduleRuleKind.host && kind != ScheduleRuleKind.wildcard) return null;
    return _numericEvasionStem(fromHost: pattern);
  }

  static String? _parseGenre(String s) {
    final lower = s.toLowerCase();
    for (final p in ['genre:', '장르:']) {
      if (lower.startsWith(p)) {
        final rest = s.substring(p.length).trim().toLowerCase();
        if (rest.isNotEmpty) return rest;
      }
    }
    return null;
  }

  static DetectedScheduleRule? _detectYoutube(String s) {
    final lower = s.toLowerCase();

    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      final vid = UrlParser.extractYouTubeVideoId(s);
      if (vid != null) {
        return DetectedScheduleRule(
          kind: ScheduleRuleKind.videoUrl,
          pattern: s.toLowerCase(),
          hint: 'YouTube 영상 1개',
        );
      }

      final ch = RegExp(r'youtube\.com/channel/(UC[\w-]+)', caseSensitive: false).firstMatch(s);
      if (ch != null) {
        return DetectedScheduleRule(
          kind: ScheduleRuleKind.channelUrl,
          pattern: ch.group(1)!.toLowerCase(),
          hint: 'YouTube 채널',
        );
      }

      final at = RegExp(r'youtube\.com/@([\w.-]+)', caseSensitive: false).firstMatch(s);
      if (at != null) {
        return DetectedScheduleRule(
          kind: ScheduleRuleKind.channelUrl,
          pattern: '@${at.group(1)!.toLowerCase()}',
          hint: 'YouTube 채널',
        );
      }

      final cslug = RegExp(r'youtube\.com/c/([\w.-]+)', caseSensitive: false).firstMatch(s);
      if (cslug != null) {
        return DetectedScheduleRule(
          kind: ScheduleRuleKind.channelUrl,
          pattern: '@${cslug.group(1)!.toLowerCase()}',
          hint: 'YouTube 채널',
        );
      }
    }

    if (RegExp(r'^@[\w.-]+$').hasMatch(s)) {
      return DetectedScheduleRule(
        kind: ScheduleRuleKind.channelUrl,
        pattern: s.toLowerCase(),
        hint: 'YouTube 채널',
      );
    }

    if (RegExp(r'^UC[\w-]{10,}$').hasMatch(s)) {
      return DetectedScheduleRule(
        kind: ScheduleRuleKind.channelUrl,
        pattern: s,
        hint: 'YouTube 채널',
      );
    }

    if (RegExp(r'^[A-Z][a-zA-Z0-9_-]{2,}$').hasMatch(s) && !s.contains('.')) {
      return DetectedScheduleRule(
        kind: ScheduleRuleKind.channelUrl,
        pattern: '@${s.toLowerCase()}',
        hint: 'YouTube 채널 (@${s.toLowerCase()})',
      );
    }

    return null;
  }

  static String? _parseUrlContains(String s) {
    final lower = s.toLowerCase();
    for (final p in ['포함:', 'contains:', 'url:']) {
      if (lower.startsWith(p)) {
        return _stripWildcards(s.substring(p.length).trim().toLowerCase());
      }
    }
    if (s.startsWith('*') && s.endsWith('*') && s.length > 2) {
      return _stripWildcards(s.substring(1, s.length - 1).toLowerCase());
    }
    if (s.endsWith('*') && s.length > 2 && !s.startsWith('*.')) {
      return _stripWildcards(s.substring(0, s.length - 1).toLowerCase());
    }
    return null;
  }

  static String _stripWildcards(String s) => s.replaceAll('*', '').trim();

  static DetectedScheduleRule? _numericEvasionContext(String raw) {
    final host = HostExpansion.canonicalHost(raw);
    if (host != null) {
      final stem = _numericEvasionStem(fromHost: host);
      if (stem != null) {
        return DetectedScheduleRule(
          kind: ScheduleRuleKind.urlContains,
          pattern: stem,
          secondaryHost: host,
          hint: '🔢 숫자 우회 패턴: \'$stem\'+숫자 변형까지 차단',
        );
      }
    }

    final tokenStem = _numericEvasionStem(fromToken: raw.trim().toLowerCase());
    if (tokenStem != null) {
      return DetectedScheduleRule(
        kind: ScheduleRuleKind.urlContains,
        pattern: tokenStem,
        hint: '🔢 숫자 우회 패턴: \'$tokenStem\'+숫자 변형까지 차단',
      );
    }
    return null;
  }

  static String? _numericEvasionStem({String? fromHost, String? fromToken}) {
    if (fromHost != null) {
      final parts = fromHost.split('.');
      if (parts.length < 2) return null;
      final label = parts.first;
      final m = RegExp(r'^([a-z-]{5,})(\d{1,4})$').firstMatch(label);
      if (m != null) return m.group(1);
      return null;
    }
    if (fromToken != null) {
      if (fromToken.contains('.')) return null;
      final m = RegExp(r'^([a-z-]{5,})(\d{2,4})$').firstMatch(fromToken);
      if (m != null) return m.group(1);
    }
    return null;
  }

  static bool _looksLikeDomain(String s) {
    if (s.contains(' ')) return false;
    if (s.startsWith('*.')) return true;
    if (RegExp(r'^https?://').hasMatch(s)) return true;
    if (s.contains('.') && !s.startsWith('@')) return true;
    return false;
  }

  static String? _variationStemForHost(String host) {
    final parts = host.split('.');
    if (parts.isEmpty) return null;
    final label = parts.first.replaceAll(RegExp(r'\d+$'), '');
    if (label.length >= 2 && label.length <= 4) return label;
    return null;
  }

  static String? _variationStemForKeyword(String kw) {
    if (kw.length >= 4) return kw;
    return null;
  }
}
