import '../ai_client.dart';
import '../../youtube/blocked_channel_store.dart';
import '../../youtube/content_filter_store.dart';
import 'block_audit_log_store.dart';
import 'block_state_snapshot_service.dart';

class BlockAuditFinding {
  const BlockAuditFinding({required this.title, required this.detail});
  final String title;
  final String detail;
}

class BlockAuditAnalysisResult {
  const BlockAuditAnalysisResult({
    required this.findings,
    required this.usedAi,
    this.aiNote,
  });

  final List<BlockAuditFinding> findings;
  final bool usedAi;
  final String? aiNote;

  bool get isEmpty => findings.isEmpty && (aiNote == null || aiNote!.isEmpty);
}

/// 최근 7일 차단 로그 + 현재 차단 데이터 → 잘못 적용된 부분 찾기
class BlockAuditAnalysisService {
  BlockAuditAnalysisService._();

  static Future<BlockAuditAnalysisResult> analyze() async {
    await BlockAuditLogStore.ensureOpen();
    final logs = BlockAuditLogStore.loadRecent();
    final findings = <BlockAuditFinding>[..._localHeuristics()];

    if (!AiClient.isConfigured) {
      return BlockAuditAnalysisResult(
        findings: findings,
        usedAi: false,
        aiNote: 'AI 키가 없어서 기본 점검만 했어요. 더 깊은 분석은 AI 허브에서 키를 등록하면 받을 수 있어요.',
      );
    }

    final logText = logs.isEmpty
        ? '(최근 7일 내 챗으로 받은 명령 없음)'
        : logs
            .map((e) =>
                '${e.at.toIso8601String()} · "${e.command}" → ${e.success ? '성공' : '실패'}: ${e.summary}'
                '${e.steps.isNotEmpty ? '\n  - ${e.steps.join('\n  - ')}' : ''}')
            .join('\n');

    final result = await AiClient.chat(
      feature: 'block_audit_analysis',
      systemPrompt:
          '너는 개인 콘텐츠 차단 앱(Isle)의 설정을 점검하는 조수야. '
          '최근 7일간 사용자가 채팅으로 내린 차단 명령·적용 결과 로그와, 현재 차단 데이터 전체 스냅샷을 받는다. '
          '다음을 찾아서 한국어로 간결하게 bullet(- ) 목록으로 답해: '
          '① 의도와 다르게 잘못 적용된 것으로 보이는 항목(너무 광범위한 키워드, 잘못 매칭됐을 채널명, 중복/모순되는 스케줄), '
          '② 사용자가 명령했지만 로그상 실패했거나 부분 적용된 것, '
          '③ 방치된 것으로 보이는 항목(오래전에 추가됐지만 최근 명령과 무관). '
          '문제가 없으면 "특별한 문제는 안 보여요" 한 줄만 답해. 각 항목은 무엇을·왜·어떻게 고치면 되는지 한 줄로.',
      userPrompt:
          '## 최근 7일 챗 명령 로그\n$logText\n\n## 현재 차단 데이터\n${BlockStateSnapshotService.buildSummary()}',
      maxTokens: 600,
      temperature: 0.3,
    );

    if (!result.usedAi || result.content.trim().isEmpty) {
      return BlockAuditAnalysisResult(
        findings: findings,
        usedAi: false,
        aiNote: 'AI 분석을 받아오지 못했어요(${result.error ?? '알 수 없는 오류'}). 기본 점검 결과만 보여드려요.',
      );
    }

    return BlockAuditAnalysisResult(
      findings: findings,
      usedAi: true,
      aiNote: result.content.trim(),
    );
  }

  /// API 없이도 바로 잡히는 명백한 문제 — 무료
  static List<BlockAuditFinding> _localHeuristics() {
    final out = <BlockAuditFinding>[];

    final channels = BlockedChannelStore.loadAll();
    final seenChannelKeys = <String>{};
    for (final c in channels) {
      final key = (c.channelId.isNotEmpty ? c.channelId : c.channelName).toLowerCase();
      if (key.isEmpty) continue;
      if (!seenChannelKeys.add(key)) {
        out.add(BlockAuditFinding(
          title: '중복 차단 채널',
          detail: '「${c.channelName.isNotEmpty ? c.channelName : c.channelId}」이 목록에 두 번 이상 있어요.',
        ));
      }
    }

    final keywords = ContentFilterStore.loadKeywords();
    for (final kw in keywords) {
      if (kw.trim().length <= 2) {
        out.add(BlockAuditFinding(
          title: '너무 짧은 키워드',
          detail: '「$kw」는 짧아서 관련 없는 영상까지 넓게 가릴 수 있어요.',
        ));
      }
    }

    return out;
  }
}
