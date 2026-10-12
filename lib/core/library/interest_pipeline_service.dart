import '../ai/ai_client.dart';
import '../services/notification_service.dart';
import 'ai_summarizer.dart';
import 'interest_pipeline_store.dart';
import 'models/interest_item.dart';
import 'models/library_entry.dart';
import 'personal_library_store.dart';

/// 관심 항목 → 기사화·병합 (앱 사용 중·피드 새로고침 시 처리, 백그라운드 폴링 없음)
class InterestPipelineService {
  InterestPipelineService._();

  static Future<int> processDueItems() async {
    final now = DateTime.now();
    var processed = 0;

    for (final item in InterestPipelineStore.loadAll()) {
      if (item.status != 'queued') continue;
      if (item.publishArticleAt.isAfter(now)) continue;

      var log = [...item.processLog, '${now.toIso8601String()} 기사 생성 시작'];
      var working = item.copyWith(status: 'processing', processLog: log);
      await InterestPipelineStore.update(working);

      final article = await AiSummarizer.summarizeArticle(
        title: item.title,
        url: item.url,
        sourceType: item.sourceType,
        channelName: item.channelName,
        feature: 'interest_article',
      );
      final usedAi = AiClient.isConfigured;
      log = [
        ...log,
        '${DateTime.now().toIso8601String()} ${usedAi ? "AI 네트워크 요약" : "로컬 요약 (데이터 전송 없음)"} 완료',
      ];

      working = working.copyWith(
        status: 'article_ready',
        articleText: article,
        processLog: log,
      );
      await InterestPipelineStore.update(working);

      if (working.mergeGroupId == null) {
        await _publishArticleEntry(working);
      }
      processed++;
    }

    await _mergeReadyGroups();
    return processed;
  }

  static Future<void> _publishArticleEntry(InterestItem item) async {
    final entry = LibraryEntry(
      id: 'article_${item.id}',
      title: item.title,
      url: item.url,
      thumbnailUrl: '',
      sourceType: item.sourceType,
      channelId: '',
      channelName: item.channelName,
      summary: item.articleText,
      origin: 'interest_article',
      importedAt: DateTime.now(),
      publishedAt: DateTime.now(),
    );
    await PersonalLibraryStore.upsertEntries([entry]);
    await NotificationService.notifyContentReady(
      title: '리포트가 도착했어요',
      body: '「${item.title}」가 읽을 수 있는 글로 만들어졌어요',
    );
  }

  /// 같은 mergeGroupId · 2개 이상 article_ready → 특별 기사 1개
  static Future<void> _mergeReadyGroups() async {
    final ready = InterestPipelineStore.loadAll()
        .where((e) => e.status == 'article_ready' && e.mergeGroupId != null)
        .toList();
    if (ready.isEmpty) return;

    final byGroup = <String, List<InterestItem>>{};
    for (final e in ready) {
      byGroup.putIfAbsent(e.mergeGroupId!, () => []).add(e);
    }

    for (final entry in byGroup.entries) {
      final group = entry.value;
      if (group.length < 2) {
        await _publishArticleEntry(group.first);
        await InterestPipelineStore.update(
          group.first.copyWith(
            status: 'published',
            processLog: [
              ...group.first.processLog,
              '${DateTime.now().toIso8601String()} 단독 기사로 피드 게시',
            ],
          ),
        );
        continue;
      }

      final pending = group.where((e) => e.publishArticleAt.isAfter(DateTime.now())).toList();
      if (pending.isNotEmpty) continue;

      final groupId = entry.key;
      final bodies = group
          .map((e) => '■ ${e.title}\n${e.articleText ?? ''}')
          .where((s) => s.trim().isNotEmpty)
          .join('\n\n');
      final mergedTitle = '관심 모아 읽기 (${group.length}편)';
      final mergedBody = '여러 「관심 있어요」를 하나의 읽기 카드로 묶었습니다.\n\n$bodies';

      final merged = LibraryEntry(
        id: 'merge_$groupId',
        title: mergedTitle,
        url: group.first.url,
        thumbnailUrl: '',
        sourceType: 'article',
        channelId: '',
        channelName: 'Isle',
        summary: mergedBody,
        origin: 'merged_article',
        importedAt: DateTime.now(),
        publishedAt: DateTime.now(),
      );
      await PersonalLibraryStore.upsertEntries([merged]);
      await NotificationService.notifyContentReady(
        title: '뉴스처럼 모아 읽기가 도착했어요',
        body: '관심 있었던 콘텐츠 ${group.length}건을 하나의 기사로 묶었어요',
      );

      for (final item in group) {
        await InterestPipelineStore.update(
          item.copyWith(
            status: 'merged',
            mergeGroupId: groupId,
            processLog: [
              ...item.processLog,
              '${DateTime.now().toIso8601String()} 특별 기사로 병합됨',
            ],
          ),
        );
      }
    }
  }
}
