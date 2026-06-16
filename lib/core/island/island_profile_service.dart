import '../../features/island/data/models/archive.dart';
import '../../features/island/data/models/island_snapshot.dart';
import '../../features/island/data/models/shelf.dart';
import '../constants/app_colors.dart';
import '../library/interest_pipeline_store.dart';
import '../library/models/library_entry.dart';
import '../library/personal_library_store.dart';
import '../services/isle_user_defaults.dart';
import '../utils/topic_matcher.dart';
import 'island_snapshot_store.dart';

/// 사용자 관심·라이브러리·관심 파이프라인 → 섬 책장 레이아웃
class IslandProfileService {
  IslandProfileService._();

  static const _tagEmojis = <String, String>{
    '기술/IT': '💻',
    '재무/투자': '📈',
    '디자인': '🎨',
    '철학/인문': '📖',
    '자기계발': '🌱',
    '라이프스타일': '☕',
    '음악': '🎵',
    '영화': '🎬',
    '과학': '🔬',
    '비즈니스': '💼',
  };

  static IslandMonthlySnapshot buildLiveProfile({String userId = 'local'}) {
    final weights = _computeInterestWeights();
    final archivesByShelf = <String, List<Archive>>{};
    final shelves = <Shelf>[];

    var x = 0;
    var y = 0;
    final sorted = weights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    for (var i = 0; i < sorted.length; i++) {
      final tag = sorted[i].key;
      final w = sorted[i].value;
      if (w <= 0) continue;

      final shelfId = 'tag_${_slug(tag)}';
      final archives = _archivesForTag(tag);
      archivesByShelf[shelfId] = archives;

      shelves.add(
        Shelf(
          id: shelfId,
          userId: userId,
          title: tag,
          description: '${archives.length}개 저장 · 가중치 ${(w * 100).round()}%',
          interestTagId: tag,
          iconEmoji: _tagEmojis[tag] ?? '📚',
          positionX: x,
          positionY: y,
          colorHex: _colorForTag(i),
          createdAt: DateTime.now(),
        ),
      );

      x = (x + 1) % 4;
      if (x == 0) y++;
    }

    if (shelves.isEmpty) {
      shelves.add(
        Shelf(
          id: 'welcome',
          userId: userId,
          title: '관심사를 골라 주세요',
          description: '설정 → 관심사 · 피드에서 콘텐츠 저장',
          iconEmoji: '🏝️',
          positionX: 0,
          positionY: 0,
          colorHex: '#2B4A8C',
          createdAt: DateTime.now(),
        ),
      );
    }

    return IslandMonthlySnapshot(
      periodKey: IslandSnapshotStore.currentPeriodKey,
      savedAt: DateTime.now(),
      shelves: shelves,
      archivesByShelfId: archivesByShelf,
      interestWeights: weights,
      summary: _buildSummary(weights, archivesByShelf),
    );
  }

  static Future<IslandMonthlySnapshot> buildForPeriod(String periodKey, {String userId = 'local'}) async {
    final saved = IslandSnapshotStore.load(periodKey);
    if (saved != null) return saved;
    return buildLiveProfile(userId: userId);
  }

  static Future<IslandMonthlySnapshot> refreshAndMaybeSave({String userId = 'local'}) async {
    final live = buildLiveProfile(userId: userId);
    await IslandSnapshotStore.rolloverIfNeeded(live);
    return live;
  }

  static Map<String, double> _computeInterestWeights() {
    final scores = <String, double>{};

    for (final tag in IsleUserDefaults.onboardingInterestTags) {
      scores[tag] = (scores[tag] ?? 0) + 3;
    }

    for (final entry in PersonalLibraryStore.loadEntries()) {
      final tags = TopicMatcher.detectTopics('${entry.title} ${entry.channelName}');
      for (final t in tags) {
        scores[t] = (scores[t] ?? 0) + 1.2;
      }
      if (entry.origin == 'watch_later') {
        scores['기술/IT'] = (scores['기술/IT'] ?? 0) + 0.3;
      }
    }

    for (final item in InterestPipelineStore.loadAll()) {
      final tags = TopicMatcher.detectTopics(item.title);
      for (final t in tags) {
        scores[t] = (scores[t] ?? 0) + (item.status == 'queued' ? 1.5 : 2.5);
      }
    }

    if (scores.isEmpty) {
      for (final t in TopicMatcher.presetInterestTags.take(4)) {
        scores[t] = 1;
      }
    }

    return scores;
  }

  static List<Archive> _archivesForTag(String tag) {
    final out = <Archive>[];
    final now = DateTime.now();

    for (final e in PersonalLibraryStore.loadEntries()) {
      final tags = TopicMatcher.detectTopics('${e.title} ${e.channelName}');
      if (!tags.contains(tag)) continue;
      out.add(_entryToArchive(e, now));
    }

    for (final item in InterestPipelineStore.loadAll()) {
      final tags = TopicMatcher.detectTopics(item.title);
      if (!tags.contains(tag)) continue;
      out.add(
        Archive(
          id: 'pipe_${item.id}',
          shelfId: 'tag_${_slug(tag)}',
          userId: 'local',
          url: item.url,
          title: item.title,
          thumbnailUrl: null,
          sourceType: item.sourceType,
          tags: tags,
          archivedAt: item.markedAt,
          isRead: item.status == 'article_ready' || item.status == 'merged',
        ),
      );
    }

    out.sort((a, b) => b.archivedAt.compareTo(a.archivedAt));
    return out.take(24).toList();
  }

  static Archive _entryToArchive(LibraryEntry e, DateTime now) {
    return Archive(
      id: e.id,
      shelfId: '',
      userId: 'local',
      url: e.url,
      title: e.title,
      thumbnailUrl: e.thumbnailUrl.isEmpty ? null : e.thumbnailUrl,
      sourceType: e.sourceType,
      tags: TopicMatcher.detectTopics('${e.title} ${e.channelName}'),
      archivedAt: e.importedAt,
      isRead: e.summary != null,
    );
  }

  static String _colorForTag(int index) {
    final c = IsleColors.tagPalette[index % IsleColors.tagPalette.length];
    final v = c.toARGB32();
    return '#${v.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  static String _slug(String tag) => tag.replaceAll('/', '_').replaceAll(' ', '_');

  static String _buildSummary(Map<String, double> weights, Map<String, List<Archive>> archives) {
    final top = weights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = archives.values.fold<int>(0, (a, b) => a + b.length);
    if (top.isEmpty) return '관심사를 설정하고 콘텐츠를 저장하면 섬이 자라요.';
    return '이번 달 ${top.first.key} 중심 · 저장 $total개 · '
        '${InterestPipelineStore.loadAll().where((e) => e.status == "queued").length}개 AI 기사 대기';
  }
}
