import 'dart:convert';

import '../../constants/app_release_info.dart';
import '../ai_usage_log_store.dart';
import 'block_chat_models.dart';

/// 차단 AI 챗 — Cursor·Claude 업그레이드용 대화보내기
class BlockChatTranscriptService {
  BlockChatTranscriptService._();

  /// 말풍선 하나 복사용 (항상 사용 가능)
  /// 버전 넘버는 항상 붙인다 — Cursor/Claude에 붙여넣을 때 어느 빌드에서
  /// 재현됐는지 바로 알 수 있어야 함(전체 대화 복사·차단 로그 복사는 이미
  /// 붙어 있었는데 이 개별 말풍선 복사만 빠져 있었음, cage에서 07-11 발견·수정
  /// 후 이식).
  static String messagePlainText(BlockChatMessage message) {
    if (message.isLoading) return '';
    final role = message.role == BlockChatRole.user ? '사용자' : 'AI';
    final buf =
        StringBuffer('[${AppReleaseInfo.label}]\n[$role]\n${message.text.trim()}');
    final result = message.result;
    if (result != null && !result.isFailure) {
      if (result.steps.isNotEmpty) {
        buf.writeln('\n\n[적용 단계]');
        for (final s in result.steps) {
          buf.writeln('- ${s.title}: ${s.detail}');
        }
      }
      if (result.permissionGaps.isNotEmpty) {
        buf.writeln('\n[수동 설정 필요]');
        for (final g in result.permissionGaps) {
          buf.writeln('- ${g.title}: ${g.issue}');
        }
      }
    }
    if (message.plan != null) {
      buf.writeln('\n[파싱 action] ${message.plan!.action}');
    }
    return buf.toString().trim();
  }

  /// 개발자용 — 세션 전체 (Claude·Cursor 붙여넣기)
  static String buildFullTranscriptForCursor(
    List<BlockChatMessage> messages, {
    DateTime? exportedAt,
  }) {
    final at = (exportedAt ?? DateTime.now()).toUtc();
    final buf = StringBuffer()
      ..writeln('=== Isle 차단 AI 챗 — 개발자용 전체 대화 ===')
      ..writeln('App: ${AppReleaseInfo.label}')
      ..writeln('Exported (UTC): ${at.toIso8601String()}')
      ..writeln('Turns: ${_exportableTurns(messages).length}')
      ..writeln()
      ..writeln(
        '아래 블록을 Cursor·Claude 채팅에 붙여넣어 '
        '파서·executor·UX 개선 요청에 사용하세요.',
      )
      ..writeln();

    var turn = 0;
    for (final m in messages) {
      if (m.isLoading) continue;
      turn++;
      final role = m.role == BlockChatRole.user ? 'USER' : 'ASSISTANT';
      final ts = m.createdAt?.toUtc().toIso8601String();
      buf.writeln('--- Turn $turn · $role${ts != null ? ' · $ts' : ''} ---');
      buf.writeln(m.text.trim());
      buf.writeln();

      if (m.role == BlockChatRole.assistant) {
        if (m.usedAi != null) {
          buf.writeln('used_ai: ${m.usedAi}');
          // AI를 실제로 태운 턴이면, 그 호출에 실제로 보낸 요청·받은 원문
          // 응답을 같이 붙인다 — "AI가 왜 이렇게 답했는지" 디버깅용
          // (2026-[REDACTED] 사용자 요청). BlockChatMessage가 ai_log_id를 직접
          // 안 들고 있어서 시간으로 가장 가까운 호출 기록을 찾는다
          // ([AiUsageLogStore.nearestByTime] 참고).
          if (m.usedAi == true && m.createdAt != null) {
            final aiLog =
                AiUsageLogStore.nearestByTime('block_chat', m.createdAt!);
            if (aiLog != null) {
              if (aiLog.systemPrompt.isNotEmpty) {
                buf.writeln(
                    'ai_system_prompt: ${jsonEncode(aiLog.systemPrompt)}');
              }
              if (aiLog.userPrompt.isNotEmpty) {
                buf.writeln('ai_user_prompt: ${jsonEncode(aiLog.userPrompt)}');
              }
              if (aiLog.rawResponse.isNotEmpty) {
                buf.writeln(
                    'ai_raw_response: ${jsonEncode(aiLog.rawResponse)}');
              }
              if (aiLog.parseError.isNotEmpty) {
                buf.writeln(
                    'ai_parse_error: ${jsonEncode(aiLog.parseError)}');
              }
              buf.writeln(
                  'ai_provider_model: ${aiLog.providerId}/${aiLog.modelId}');
            } else {
              buf.writeln('ai_debug: (호출 기록을 못 찾음 — 20초 창 밖이거나 이미 정리됨)');
            }
          }
        }
        final plan = m.plan;
        if (plan != null) {
          buf.writeln('plan_action: ${plan.action}');
          final planJson = planToMap(plan);
          if (planJson.isNotEmpty) {
            buf.writeln('plan_json: ${jsonEncode(planJson)}');
          }
        }
        final result = m.result;
        if (result != null) {
          buf.writeln('result_failure: ${result.isFailure}');
          if (result.summary.trim().isNotEmpty &&
              result.summary.trim() != m.text.trim()) {
            buf.writeln('result_summary: ${result.summary.trim()}');
          }
          if (result.steps.isNotEmpty) {
            buf.writeln('result_steps:');
            for (final s in result.steps) {
              buf.writeln('  - ${s.title} | ${s.detail.replaceAll('\n', ' ')}');
            }
          }
          if (result.permissionGaps.isNotEmpty) {
            buf.writeln('permission_gaps:');
            for (final g in result.permissionGaps) {
              buf.writeln('  - ${g.kind.name} | ${g.title}');
            }
          }
          final coach = result.coach;
          if (coach != null && !coach.isEmpty) {
            buf.writeln('coach_insight: ${coach.usageInsight}');
          }
        }
        buf.writeln();
      }
    }

    buf.writeln('=== END ===');
    return buf.toString();
  }

  static List<BlockChatMessage> _exportableTurns(List<BlockChatMessage> messages) =>
      messages.where((m) => !m.isLoading).toList();

  static Map<String, dynamic> planToMap(BlockChatPlan plan) {
    final m = <String, dynamic>{'action': plan.action};
    void put(String k, Object? v) {
      if (v == null) return;
      if (v is String && v.trim().isEmpty) return;
      m[k] = v;
    }

    put('reply', plan.reply);
    put('keyword', plan.keyword);
    put('schedule_name', plan.scheduleName);
    put('end_hour', plan.endHour);
    put('end_minute', plan.endMinute);
    put('start_hour', plan.startHour);
    put('start_minute', plan.startMinute);
    if (plan.days.length != 7) m['days'] = plan.days;
    if (plan.blockSafariNote) m['block_safari'] = true;
    if (plan.blockIsleYoutube) m['block_isle_youtube'] = true;
    put('app_id', plan.appId);
    put('daily_minutes', plan.dailyMinutes);
    put('session_minutes', plan.sessionMinutes);
    put('cooldown_minutes', plan.cooldownMinutes);
    put('remove_schedule_query', plan.removeScheduleQuery);
    put('schedule_query', plan.scheduleQuery);
    put('schedule_new_name', plan.scheduleNewName);
    put('remove_keyword', plan.removeKeyword);
    put('remove_url', plan.removeUrl);
    put('relax_target', plan.relaxTarget);
    put('toggle_on', plan.toggleOn);
    put('limit_platform', plan.limitPlatform);
    if (plan.suggestTimelock) m['suggest_timelock'] = true;
    put('window_minutes', plan.windowMinutes);
    put('channel_name', plan.channelName);
    put('website_domain', plan.websiteDomain);
    put('pause_minutes', plan.pauseMinutes);
    put('persona_id', plan.personaId);
    return m;
  }
}
