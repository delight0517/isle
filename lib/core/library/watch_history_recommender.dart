import 'models/library_entry.dart';
import 'personal_library_store.dart';

/// 시청 이력 → 채널·토픽 빈도 집계 (로컬 휴리스틱, API 없음)
/// 피드 부스트에 자동 반영 — "자주 본 채널 비슷한 영상을 위로"
class WatchHistoryRecommender {
  WatchHistoryRecommender._();

  static const _recentDays = 45;
  static const _maxChannelBoost = 0.32;

  /// channelKey(lower) → 점수 (0.0~0.32)
  /// channelKey 우선순위: channelId(있으면) → channelName.toLowerCase()
  static Map<String, double> channelBoosts() {
    final now = DateTime.now();
    final freq = <String, double>{};
    final names = <String, String>{};

    final entries = PersonalLibraryStore.loadEntries();
    for (final e in entries) {
      if (e.sourceType != 'youtube') continue;
      if (e.origin != 'youtube_history' && e.origin != 'watch_later') continue;
      final age = now.difference(e.importedAt).inDays;
      if (age > _recentDays) continue;

      final id = e.channelId.trim();
      final nm = e.channelName.trim();
      if (id.isEmpty && nm.isEmpty) continue;
      final key = (id.isNotEmpty ? id : nm).toLowerCase();

      // 최근일수록 가중치 ↑ (1.0 → 0.4 선형 감쇠)
      final recency = 1.0 - (age / _recentDays) * 0.6;
      freq[key] = (freq[key] ?? 0) + recency;
      if (nm.isNotEmpty && !names.containsKey(key)) names[key] = nm;
    }

    // 점수 → 0.08(1회 시청) ~ _maxChannelBoost(누적)
    final boosts = <String, double>{};
    for (final entry in freq.entries) {
      final score = (entry.value * 0.10).clamp(0.0, _maxChannelBoost);
      if (score > 0.02) boosts[entry.key] = score;
    }
    return boosts;
  }

  /// 추천 이유 표시용 — 채널 이름 매핑
  static Map<String, String> channelNamesByKey() {
    final entries = PersonalLibraryStore.loadEntries();
    final out = <String, String>{};
    for (final e in entries) {
      if (e.sourceType != 'youtube') continue;
      if (e.channelName.isEmpty) continue;
      final key = (e.channelId.isNotEmpty ? e.channelId : e.channelName).toLowerCase();
      out.putIfAbsent(key, () => e.channelName);
    }
    return out;
  }

  /// 진단용 — 상위 추천 채널 N개
  static List<({String channelName, double score})> topChannels({int limit = 5}) {
    final boosts = channelBoosts();
    final names = channelNamesByKey();
    final list = boosts.entries
        .map((e) => (channelName: names[e.key] ?? e.key, score: e.value))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return list.take(limit).toList();
  }

  /// 피드 아이템 키 매칭 — `FeedItem.channelId` / `channelName` 어느 쪽이든
  static double boostForItem({required String channelId, required String channelName}) {
    final boosts = channelBoosts();
    final byId = channelId.trim().toLowerCase();
    final byName = channelName.trim().toLowerCase();
    if (byId.isNotEmpty && boosts.containsKey(byId)) return boosts[byId]!;
    if (byName.isNotEmpty && boosts.containsKey(byName)) return boosts[byName]!;
    return 0.0;
  }

  /// 라이브러리 항목 직접 사용 (캐시 없이 빠른 매칭)
  static double boostForEntry(LibraryEntry entry) =>
      boostForItem(channelId: entry.channelId, channelName: entry.channelName);
}
