class IosFamilyActivityPickResult {
  const IosFamilyActivityPickResult({
    required this.encoded,
    required this.applicationCount,
    required this.categoryCount,
    required this.webDomainCount,
  });

  final String encoded;
  final int applicationCount;
  final int categoryCount;
  final int webDomainCount;

  factory IosFamilyActivityPickResult.fromMap(Map<String, dynamic> map) {
    return IosFamilyActivityPickResult(
      encoded: map['encoded'] as String? ?? '',
      applicationCount: (map['applicationCount'] as num?)?.toInt() ?? 0,
      categoryCount: (map['categoryCount'] as num?)?.toInt() ?? 0,
      webDomainCount: (map['webDomainCount'] as num?)?.toInt() ?? 0,
    );
  }
}
