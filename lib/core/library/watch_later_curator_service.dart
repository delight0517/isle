import '../ai/ai_client.dart';
import 'ai_summarizer.dart';
import 'models/library_entry.dart';
import 'personal_library_store.dart';

/// 나중에 볼 목록 중 최신 [newestFraction] 비율만 샘플 → 피드 추천 카드
class WatchLaterCuratorService {
  WatchLaterCuratorService._();

  static Future<int> buildCuratedSuggestions({double newestFraction = 0.3}) async {
    final all = PersonalLibraryStore.loadEntries()
        .where((e) => e.origin == 'watch_later' || e.origin == 'youtube_history')
        .toList();
    if (all.isEmpty) return 0;

    all.sort((a, b) => b.importedAt.compareTo(a.importedAt));
    final take = (all.length * newestFraction).ceil().clamp(1, all.length);
    final sample = all.take(take).toList();

    final useAi = AiClient.isConfigured;

    final out = <LibraryEntry>[];
    for (final src in sample) {
      String blurb;
      if (useAi) {
        blurb = await AiSummarizer.summarizeArticle(
          title: src.title,
          url: src.url,
          sourceType: src.sourceType,
          channelName: src.channelName,
          feature: 'watch_later_curate',
        );
      } else {
        blurb =
            '나중에 볼 목록 기반 추천 — 「${src.title}」${src.channelName.isNotEmpty ? ' · ${src.channelName}' : ''}';
      }
      out.add(
        LibraryEntry(
          id: 'curated_${src.id}',
          title: '추천: ${src.title}',
          url: src.url,
          thumbnailUrl: src.thumbnailUrl,
          sourceType: src.sourceType,
          channelId: src.channelId,
          channelName: src.channelName,
          summary: blurb,
          origin: 'curated_suggestion',
          importedAt: DateTime.now(),
          publishedAt: DateTime.now(),
        ),
      );
    }
    return PersonalLibraryStore.upsertEntries(out);
  }
}
