import '../intervention/website_block_store.dart';
import '../youtube/block_keyword_policy.dart';
import 'models/premade_block_pack.dart';

/// 팩 항목 1개가 만들 수 있는 provenance 후보 (제거·상태 표시용)
class PremadeBlockPackEntryEffects {
  PremadeBlockPackEntryEffects._();

  /// 채널 ID(예: `UC4P7F8qenDo1O_5NvgBb_cg`)는 @handle이 아니다 — 그대로
  /// 소문자화+`@` 접두사를 붙이면 실제 매칭에 쓰이는
  /// `YoutubeChannelPatternNormalizer.normalizeEntry`(대소문자 보존, `@` 없음)와
  /// 영원히 어긋나는 문자열이 저장돼 그 채널은 프리셋에 있어도 실제로는 절대
  /// 차단되지 않는 실사용 버그였다(2026-07-16, 게임 프리셋 채널 미차단 제보로
  /// 발견 — "스타" UC4P7F8qenDo1O_5NvgBb_cg가 `@uc4p7f8qendo1o_5nvgbb_cg`로
  /// 저장돼 실제 채널과 매치될 수 없었음). 채널 ID 패턴이면 원형 그대로 두고,
  /// 진짜 handle만 `@` 접두사·소문자화한다.
  static String normalizeHandle(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (RegExp(r'^UC[\w-]{10,}$', caseSensitive: false).hasMatch(trimmed)) {
      return trimmed;
    }
    var h = trimmed.toLowerCase();
    if (!h.startsWith('@')) h = '@$h';
    return h;
  }

  static List<PremadePackProvenanceEntry> provenanceCandidates(PremadeBlockPackEntry entry) {
    final out = <PremadePackProvenanceEntry>[];
    void add(String storeKind, String value) {
      final v = value.trim();
      if (v.isEmpty) return;
      out.add(PremadePackProvenanceEntry(storeKind: storeKind, value: v));
    }

    switch (entry.kind) {
      case 'channelURL':
        final handle = normalizeHandle(entry.pattern);
        if (handle.isEmpty) break;
        add('channel', handle);
        add('url', 'https://www.youtube.com/$handle');
      case 'host':
      case 'wildcard':
        final rawPattern = entry.pattern.trim();
        if (rawPattern.contains('/')) {
          final urlRule =
              rawPattern.startsWith('http') ? rawPattern : 'https://$rawPattern';
          add('url', urlRule);
          break;
        }
        final domain = WebsiteBlockStore.normalizeDomain(entry.pattern) ??
            entry.pattern.trim().toLowerCase().split('/').first;
        if (domain.isEmpty || !BlockKeywordPolicy.isSafePremadeWebsiteDomain(domain)) {
          break;
        }
        add('domain', domain);
        if (BlockKeywordPolicy.isSafePremadeKeyword(domain)) {
          add('keyword', domain);
        }
        final stem = domain.split('.').first;
        if (stem.length >= 6 && BlockKeywordPolicy.isSafePremadeKeyword(stem)) {
          add('keyword', stem);
        }
        add('url', 'https://$domain');
      case 'keyword':
        final k = entry.pattern.trim().toLowerCase();
        if (BlockKeywordPolicy.isSafePremadeKeyword(k)) add('keyword', k);
      case 'urlContains':
      case 'videoURL':
        final url = entry.pattern.trim();
        if (url.isEmpty) break;
        add('url', url.startsWith('http') ? url : 'https://$url');
      default:
        break;
    }
    return out;
  }

  static String provenanceKey(PremadePackProvenanceEntry e) =>
      '${e.storeKind}|${e.value.toLowerCase()}';

  static String kindLabelKo(String kind) => switch (kind) {
        'channelURL' => '채널',
        'host' => '도메인',
        'wildcard' => '와일드카드',
        'keyword' => '키워드',
        'urlContains' => 'URL',
        'videoURL' => '영상',
        _ => kind,
      };
}
