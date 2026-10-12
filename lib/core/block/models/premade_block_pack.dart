class PremadeBlockPackEntry {
  const PremadeBlockPackEntry({
    required this.pattern,
    required this.kind,
    this.note,
  });

  final String pattern;
  final String kind;
  final String? note;

  Map<String, dynamic> toJson() => {
        'pattern': pattern,
        'kind': kind,
        if (note != null) 'note': note,
      };

  factory PremadeBlockPackEntry.fromJson(Map<String, dynamic> j) =>
      PremadeBlockPackEntry(
        pattern: j['pattern'] as String? ?? '',
        kind: j['kind'] as String? ?? '',
        note: j['note'] as String?,
      );

  String get dedupeKey => '${pattern.toLowerCase()}|${kind.toLowerCase()}';
}

class PremadeBlockPack {
  const PremadeBlockPack({
    required this.packId,
    required this.displayName,
    required this.description,
    required this.version,
    required this.generatedAt,
    required this.entryCount,
    required this.entries,
    required this.assetPath,
  });

  final String packId;
  final String displayName;
  final String description;
  final String version;
  final String generatedAt;
  final int entryCount;
  final List<PremadeBlockPackEntry> entries;
  final String assetPath;

  factory PremadeBlockPack.fromJson(Map<String, dynamic> j, {required String assetPath}) {
    final raw = j['entries'] as List<dynamic>? ?? [];
    return PremadeBlockPack(
      packId: j['packId'] as String? ?? '',
      displayName: j['displayName'] as String? ?? '',
      description: j['description'] as String? ?? '',
      version: j['version'] as String? ?? '1.0.0',
      generatedAt: j['generatedAt'] as String? ?? '',
      entryCount: (j['entryCount'] as num?)?.toInt() ?? raw.length,
      entries: raw
          .map((e) => PremadeBlockPackEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((e) => e.pattern.isNotEmpty && e.kind.isNotEmpty)
          .toList(),
      assetPath: assetPath,
    );
  }
}

/// 팩 적용 시 실제 추가된 항목 — 제거 시 역추적용
class PremadePackProvenanceEntry {
  const PremadePackProvenanceEntry({
    required this.storeKind,
    required this.value,
  });

  /// channel · keyword · url · domain
  final String storeKind;
  final String value;

  Map<String, dynamic> toJson() => {
        'storeKind': storeKind,
        'value': value,
      };

  factory PremadePackProvenanceEntry.fromJson(Map<String, dynamic> j) =>
      PremadePackProvenanceEntry(
        storeKind: j['storeKind'] as String? ?? '',
        value: j['value'] as String? ?? '',
      );
}

enum PremadePackEntryStatus {
  notApplied,
  active,
  excluded,
  pending,
}

class PremadeBlockPackApplyResult {
  const PremadeBlockPackApplyResult({
    required this.packId,
    required this.channelsAdded,
    required this.keywordsAdded,
    required this.urlsAdded,
    required this.domainsAdded,
    required this.skipped,
  });

  final String packId;
  final int channelsAdded;
  final int keywordsAdded;
  final int urlsAdded;
  final int domainsAdded;
  final int skipped;

  int get totalAdded => channelsAdded + keywordsAdded + urlsAdded + domainsAdded;

  String summary(String displayName) {
    if (totalAdded == 0 && skipped > 0) {
      return '「$displayName」 — 이미 모두 차단 목록에 있어요';
    }
    final parts = <String>[];
    if (channelsAdded > 0) parts.add('채널 $channelsAdded');
    if (keywordsAdded > 0) parts.add('키워드 $keywordsAdded');
    if (urlsAdded > 0) parts.add('URL $urlsAdded');
    if (domainsAdded > 0) parts.add('사이트 $domainsAdded');
    final body = parts.isEmpty ? '추가 0' : parts.join(' · ');
    final skip = skipped > 0 ? ' (중복 $skipped)' : '';
    return '「$displayName」 적용 — $body$skip';
  }
}
