import '../services/isle_user_defaults.dart';
import 'ai_summarizer.dart';
import 'models/library_entry.dart';
import 'personal_library_store.dart';

/// 시청·가져온 콘텐츠를 주 N회 요약 카드로 승격 (로컬만)
class DigestScheduler {
  DigestScheduler._();

  static bool canPublishDigestThisWeek() {
    if (!IsleUserDefaults.digestToFeedEnabled) return false;
    final last = IsleUserDefaults.digestLastPublishedAt;
    final count = IsleUserDefaults.digestPublishedThisWeek;
    final max = IsleUserDefaults.digestMaxPerWeek;
    if (last == null) return count < max;
    final now = DateTime.now();
    final sameWeek = _isoWeek(now) == _isoWeek(last);
    if (!sameWeek) return true;
    return count < max;
  }

  static int _isoWeek(DateTime d) {
    final thursday = d.add(Duration(days: 4 - (d.weekday)));
    final yearStart = DateTime(thursday.year);
    return ((thursday.difference(yearStart).inDays) / 7).floor();
  }

  /// 상호작용·최신 순으로 요약 없는 항목에 summary 부여
  static Future<int> runIfAllowed() async {
    if (!canPublishDigestThisWeek()) return 0;

    final entries = PersonalLibraryStore.loadEntries()
        .where((e) => e.summary == null || e.summary!.trim().isEmpty)
        .toList();
    if (entries.isEmpty) return 0;

    entries.sort((a, b) => b.importedAt.compareTo(a.importedAt));

    final max = IsleUserDefaults.digestMaxPerWeek - IsleUserDefaults.digestPublishedThisWeek;
    if (max <= 0) return 0;

    var published = 0;
    final list = PersonalLibraryStore.loadEntries();

    for (final e in entries.take(max)) {
      final summary = await AiSummarizer.summarizeArticle(
        title: e.title,
        url: e.url,
        sourceType: e.sourceType,
        channelName: e.channelName,
      );
      final idx = list.indexWhere((x) => x.url == e.url);
      if (idx < 0) continue;
      final old = list[idx];
      list[idx] = LibraryEntry(
        id: old.id,
        title: old.title,
        url: old.url,
        thumbnailUrl: old.thumbnailUrl,
        sourceType: old.sourceType,
        channelId: old.channelId,
        channelName: old.channelName,
        summary: summary,
        origin: old.origin == 'digest' ? 'digest' : '${old.origin}_digest',
        sourceId: old.sourceId,
        importedAt: old.importedAt,
        publishedAt: DateTime.now(),
      );
      published++;
    }

    if (published > 0) {
      await PersonalLibraryStore.saveEntries(list);
      await IsleUserDefaults.recordDigestPublished(published);
    }
    return published;
  }
}
