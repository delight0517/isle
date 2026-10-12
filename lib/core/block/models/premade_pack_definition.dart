/// 4VPN manifest.json 한 줄 — 프리셋 등록·UI·스케줄 정책
enum PremadePackCategory {
  adult('adult', '성인'),
  illegal('illegal', '불법·유해'),
  gaming('gaming', '게임'),
  gambling('gambling', '도박·토토'),
  other('other', '기타');

  const PremadePackCategory(this.key, this.labelKo);

  final String key;
  final String labelKo;

  static PremadePackCategory fromKey(String? raw) {
    for (final c in values) {
      if (c.key == raw) return c;
    }
    return PremadePackCategory.other;
  }
}

enum PremadePackUiMode {
  /// [AdultProtectionService] 전용 (끔/기본/강화)
  adultProtection('adult_protection'),
  /// 보호 필터 토글 · 자동 동기화
  toggle('toggle'),
  /// 스케줄 연결만 (향후)
  scheduleOnly('schedule_only');

  const PremadePackUiMode(this.key);

  final String key;

  static PremadePackUiMode fromKey(String? raw) {
    for (final m in values) {
      if (m.key == raw) return m;
    }
    return PremadePackUiMode.toggle;
  }
}

enum PremadePackKind {
  single,
  merge,
}

class PremadePackDefinition {
  const PremadePackDefinition({
    required this.packId,
    required this.kind,
    required this.category,
    required this.uiMode,
    required this.scheduleEligible,
    this.displayName,
    this.description,
    this.sourceAsset,
    this.mergeSourceAssets = const [],
    this.legacyIds = const [],
    this.retiredStandaloneIds = const [],
    this.sensitive = false,
  });

  final String packId;
  final PremadePackKind kind;
  final PremadePackCategory category;
  final PremadePackUiMode uiMode;
  final bool scheduleEligible;
  final String? displayName;
  final String? description;
  final String? sourceAsset;
  final List<String> mergeSourceAssets;
  final List<String> legacyIds;
  final List<String> retiredStandaloneIds;
  final bool sensitive;

  bool get isAdult => category == PremadePackCategory.adult;

  factory PremadePackDefinition.fromJson(Map<String, dynamic> j) {
    final kindRaw = j['kind'] as String? ?? 'single';
    final mergeRaw = (j['mergeSources'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];
    return PremadePackDefinition(
      packId: j['packId'] as String? ?? '',
      kind: kindRaw == 'merge' ? PremadePackKind.merge : PremadePackKind.single,
      category: PremadePackCategory.fromKey(j['category'] as String?),
      uiMode: PremadePackUiMode.fromKey(j['uiMode'] as String?),
      scheduleEligible: j['scheduleEligible'] as bool? ?? true,
      displayName: j['displayName'] as String?,
      description: j['description'] as String?,
      sourceAsset: j['source'] as String?,
      mergeSourceAssets: mergeRaw,
      legacyIds: (j['legacyIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      retiredStandaloneIds: (j['retiredStandaloneIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      sensitive: j['sensitive'] as bool? ?? false,
    );
  }
}
