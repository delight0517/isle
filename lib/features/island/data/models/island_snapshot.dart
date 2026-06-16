import 'shelf.dart';
import 'archive.dart';

/// 월별 섬 스냅샷 — 관심사·저장 콘텐츠 기반
class IslandMonthlySnapshot {
  const IslandMonthlySnapshot({
    required this.periodKey,
    required this.savedAt,
    required this.shelves,
    required this.archivesByShelfId,
    required this.interestWeights,
    required this.summary,
  });

  final String periodKey;
  final DateTime savedAt;
  final List<Shelf> shelves;
  final Map<String, List<Archive>> archivesByShelfId;
  final Map<String, double> interestWeights;
  final String summary;

  factory IslandMonthlySnapshot.fromJson(Map<String, dynamic> j) {
    final shelves = (j['shelves'] as List? ?? [])
        .map((e) => Shelf.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final archivesRaw = j['archives_by_shelf'] as Map? ?? {};
    final archivesByShelfId = <String, List<Archive>>{};
    for (final entry in archivesRaw.entries) {
      final list = (entry.value as List? ?? [])
          .map((e) => Archive.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      archivesByShelfId[entry.key.toString()] = list;
    }
    final weightsRaw = j['interest_weights'] as Map? ?? {};
    final weights = weightsRaw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));

    return IslandMonthlySnapshot(
      periodKey: j['period_key'] as String? ?? '',
      savedAt: DateTime.tryParse(j['saved_at'] as String? ?? '') ?? DateTime.now(),
      shelves: shelves,
      archivesByShelfId: archivesByShelfId,
      interestWeights: weights,
      summary: j['summary'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'period_key': periodKey,
        'saved_at': savedAt.toIso8601String(),
        'shelves': shelves.map((s) => s.toJson()).toList(),
        'archives_by_shelf': archivesByShelfId.map(
          (k, v) => MapEntry(k, v.map((a) => a.toJson()).toList()),
        ),
        'interest_weights': interestWeights,
        'summary': summary,
      };
}
