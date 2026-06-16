/// 카카오톡 쇼츠 시청 세션 (수동·추후 OS 사용량)
class KakaoShortsSession {
  const KakaoShortsSession({
    required this.id,
    required this.startMs,
    this.endMs,
    this.source = KakaoShortsSessionSource.manual,
  });

  final String id;
  final int startMs;
  final int? endMs;
  final KakaoShortsSessionSource source;

  bool get isOpen => endMs == null;

  int durationSeconds({int? nowMs}) {
    final end = endMs ?? nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return ((end - startMs) / 1000).floor().clamp(0, 86400);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start_ms': startMs,
        if (endMs != null) 'end_ms': endMs,
        'source': source.name,
      };

  factory KakaoShortsSession.fromJson(Map<String, dynamic> j) => KakaoShortsSession(
        id: j['id'] as String? ?? '',
        startMs: (j['start_ms'] as num?)?.toInt() ?? 0,
        endMs: (j['end_ms'] as num?)?.toInt(),
        source: KakaoShortsSessionSource.values.firstWhere(
          (e) => e.name == j['source'],
          orElse: () => KakaoShortsSessionSource.manual,
        ),
      );
}

enum KakaoShortsSessionSource { manual, androidUsage }
