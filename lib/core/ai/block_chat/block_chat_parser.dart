import 'dart:convert';

import '../ai_client.dart';
import 'block_chat_models.dart';

/// 자연어 → 차단 설정 계획 (AI + 로컬 폴백)
class BlockChatParser {
  BlockChatParser._();

  static const _system = '''
당신은 Isle 앱의 차단·한도 설정 도우미입니다. 사용자 요청을 JSON 하나로만 답하세요.

action 목록:
- add_keyword: 유튜브·피드 키워드 숨김 (keyword 필수) — 스케줄·시간 표현은 키워드로 쓰지 마세요
- remove_keyword: 키워드 제거 (remove_keyword)
- morning_schedule: 매일 0시~지정 시각까지 차단 (schedule_name, end_hour, end_minute)
  - block_safari:true → Safari·Isle 웹 전체
  - block_isle_youtube:true → Isle 인앱 유튜브만 (「isle 유튜브」「앱 유튜브」)
- app_session_limit: 앱 일일 한도 + 세션·쿨다운 (app_id: instagram|tiktok|youtube_app, daily_minutes, session_minutes, cooldown_minutes)
- remove_schedule: 스케줄 해제 (remove_schedule_query)
- toggle_shorts / toggle_reels
- youtube_limit: Isle 유튜브 일일 한도 분 (daily_minutes)
- explain: 설정 불가·추가 질문

JSON: action, reply, keyword, schedule_name, end_hour, end_minute, days,
block_safari, block_isle_youtube, app_id, daily_minutes, session_minutes, cooldown_minutes,
remove_schedule_query, remove_keyword, toggle_on

예: "매일 10시30분까지 isle 유튜브 차단" → morning_schedule, end_hour:10, end_minute:30, block_isle_youtube:true
예: "매일 9시까지 Safari 막아줘" → morning_schedule, end_hour:9, block_safari:true
''';

  static Future<(BlockChatPlan plan, bool usedAi)> parse(String userText) async {
    final local = _parseLocal(userText);
    if (local != null) return (local, false);

    if (!AiClient.isConfigured) {
      return (
        BlockChatPlan(
          action: 'explain',
          reply: 'API 키가 없거나 예산이 0이에요. AI 센터에서 키 저장·예산(최소 \$1)을 확인해 주세요.',
        ),
        false,
      );
    }

    final ai = await AiClient.chat(
      feature: 'block_chat',
      systemPrompt: _system,
      userPrompt: userText,
      maxTokens: 400,
      temperature: 0.2,
      jsonObject: true,
    );

    if (ai.error == 'budget') {
      return (
        const BlockChatPlan(
          action: 'explain',
          reply: '월 예산이 0이거나 한도를 넘었어요. AI 센터 → 예산 슬라이더를 \$1 이상으로 올려 주세요.',
        ),
        false,
      );
    }

    if (ai.usedAi && ai.content.isNotEmpty) {
      try {
        final j = jsonDecode(ai.content) as Map<String, dynamic>;
        return (BlockChatPlan.fromJson(j), true);
      } catch (_) {}
    }

    if (ai.error != null && ai.error!.isNotEmpty) {
      return (
        BlockChatPlan(
          action: 'explain',
          reply: 'AI 연결 실패: ${ai.error}\n키·모델·Base URL을 AI 센터에서 확인해 주세요.',
        ),
        false,
      );
    }

    return (
      BlockChatPlan(
        action: 'explain',
        reply: '요청을 이해하지 못했어요. 예: 「매일 10시30분까지 isle 유튜브 차단」, '
            '「매일 9시까지 Safari 차단」, 「유튜브 하루 20분」',
      ),
      ai.usedAi,
    );
  }

  static BlockChatPlan? _parseLocal(String raw) {
    final t = raw.toLowerCase().trim();
    if (t.isEmpty) return null;

    final shorts = _parseShortsToggle(t);
    if (shorts != null) return shorts;

    final reels = _parseReelsToggle(t);
    if (reels != null) return reels;

    final isleYt = _parseIsleYoutubeSchedule(raw, t);
    if (isleYt != null) return isleYt;

    final ytLimit = _parseYoutubeLimit(t);
    if (ytLimit != null) return ytLimit;

    if (_hasAny(t, ['사파리', 'safari']) &&
        _hasAny(t, ['막', '차단', '블락', '블록', 'block'])) {
      final time = _parseEndTime(t);
      if (time != null) {
        return BlockChatPlan(
          action: 'morning_schedule',
          scheduleName: '아침 Safari 차단',
          endHour: time.$1,
          endMinute: time.$2,
          blockSafariNote: true,
          reply: '매일 0시~${_fmt(time.$1, time.$2)} 스케줄 — Isle 웹·Safari 차단',
        );
      }
    }

    if (_hasAny(t, ['스타크래프트', 'starcraft', '스타']) &&
        _hasAny(t, ['블락', '블록', '차단', '숨김', '안 보', 'block', '그만'])) {
      return const BlockChatPlan(
        action: 'add_keyword',
        keyword: '스타크래프트',
        reply: '유튜브·피드에서 「스타크래프트」 키워드를 숨깁니다.',
      );
    }

    final noMore = _extractNoMoreKeyword(raw, t);
    if (noMore != null &&
        _hasAny(t, ['블락', '블록', '차단', '숨김', '그만', '안 보', 'block'])) {
      return BlockChatPlan(
        action: 'add_keyword',
        keyword: noMore,
        reply: '키워드 「$noMore」를 숨깁니다.',
      );
    }

    final ytKw = _extractYoutubeKeyword(raw, t);
    if (ytKw != null) {
      return BlockChatPlan(
        action: 'add_keyword',
        keyword: ytKw,
        reply: '키워드 「$ytKw」를 숨깁니다.',
      );
    }

    final session = _parseAppSessionLimit(t);
    if (session != null) return session;

    if (_hasAny(t, ['키워드', 'keyword']) &&
        _hasAny(t, ['제거', '해제', '풀어', '삭제', 'remove'])) {
      final kw = _extractQuoted(raw) ?? _extractBeforeBlock(t);
      if (kw != null) {
        return BlockChatPlan(
          action: 'remove_keyword',
          removeKeyword: kw,
          reply: '키워드 「$kw」를 제거합니다.',
        );
      }
    }

    if (_hasAny(t, ['스케줄', 'schedule']) &&
        _hasAny(t, ['제거', '해제', '풀어', '삭제', 'unblock', '끄', '없애'])) {
      String? q;
      if (t.contains('사파리') || t.contains('safari')) q = 'safari';
      if (t.contains('인스타')) q = '인스타';
      if (t.contains('유튜브') || t.contains('youtube')) q = '유튜브';
      return BlockChatPlan(
        action: 'remove_schedule',
        removeScheduleQuery: q ?? '',
        reply: q != null && q.isNotEmpty
            ? '「$q」 스케줄 해제 — 타임락이 켜져 있으면 대기가 시작됩니다.'
            : '스케줄 해제 — 타임락 대기를 시작할 수 있어요.',
      );
    }

    if (_looksLikeSchedule(t)) return null;

    final quoted = _extractQuoted(raw);
    if (quoted != null &&
        _hasAny(t, ['블락', '블록', '차단', '숨김', '키워드', 'block'])) {
      return BlockChatPlan(
        action: 'add_keyword',
        keyword: quoted,
        reply: '키워드 「$quoted」를 숨깁니다.',
      );
    }

    final beforeBlock = _extractBeforeBlock(t);
    if (beforeBlock != null &&
        _hasAny(t, ['블락', '블록', '차단', '숨김', 'block'])) {
      return BlockChatPlan(
        action: 'add_keyword',
        keyword: beforeBlock,
        reply: '키워드 「$beforeBlock」를 숨깁니다.',
      );
    }

    return null;
  }

  static BlockChatPlan? _parseIsleYoutubeSchedule(String raw, String t) {
    if (!_hasAny(t, ['유튜브', 'youtube'])) return null;
    if (!_hasAny(t, ['막', '차단', '블락', '블록', 'block', '금지'])) return null;
    final isIsle = _hasAny(t, ['isle', '이슬', '이젤', '앱 안', '인앱', '앱']);
    final hasTime = _parseEndTime(t) != null || _hasAny(t, ['매일', '아침', '까지', '시']);
    if (!isIsle && !hasTime) return null;

    final time = _parseEndTime(t);
    if (time == null && !_hasAny(t, ['매일', '아침'])) return null;

    final hour = time?.$1 ?? 9;
    final minute = time?.$2 ?? 0;

    return BlockChatPlan(
      action: 'morning_schedule',
      scheduleName: '아침 Isle 유튜브',
      endHour: hour,
      endMinute: minute,
      blockIsleYoutube: true,
      reply: '매일 0시~${_fmt(hour, minute)} Isle 인앱 유튜브를 막는 스케줄을 만듭니다.',
    );
  }

  static bool _looksLikeSchedule(String t) {
    return _hasAny(t, ['매일', '아침', '저녁', '스케줄', '까지']) &&
        _hasAny(t, ['시', '분', ':']) &&
        _hasAny(t, ['막', '차단', '블락', '블록', 'block']);
  }

  static String _fmt(int h, int m) =>
      m > 0 ? '$h시 $m분' : '$h시';

  static BlockChatPlan? _parseShortsToggle(String t) {
    if (!_hasAny(t, ['숏츠', 'shorts', '숏폼'])) return null;
    if (!_hasAny(t, ['숨김', '숨기', '숨겨', '끄', '막', '켜', '보이', '해제', '풀어'])) {
      return null;
    }
    final show = _hasAny(t, ['켜', '보이', '해제', '풀어', '다시']);
    final hide = _hasAny(t, ['숨김', '숨기', '숨겨', '끄', '막', '없애']);
    final on = hide && !show ? true : (show && !hide ? false : true);
    return BlockChatPlan(
      action: 'toggle_shorts',
      toggleOn: on,
      reply: on ? 'YouTube Shorts 숨김을 켭니다.' : 'YouTube Shorts를 다시 보이게 합니다.',
    );
  }

  static BlockChatPlan? _parseReelsToggle(String t) {
    if (!_hasAny(t, ['릴', 'reels', '릴스'])) return null;
    if (!_hasAny(t, ['숨김', '숨기', '숨겨', '끄', '막', '켜', '보이', '해제', '풀어'])) {
      return null;
    }
    final show = _hasAny(t, ['켜', '보이', '해제', '풀어', '다시']);
    final hide = _hasAny(t, ['숨김', '숨기', '숨겨', '끄', '막', '없애']);
    final on = hide && !show ? true : (show && !hide ? false : true);
    return BlockChatPlan(
      action: 'toggle_reels',
      toggleOn: on,
      reply: on ? 'Instagram Reels 숨김을 켭니다.' : 'Instagram Reels를 다시 보이게 합니다.',
    );
  }

  static BlockChatPlan? _parseYoutubeLimit(String t) {
    if (_looksLikeSchedule(t)) return null;
    if (!_hasAny(t, ['유튜브', 'youtube'])) return null;
    if (!_hasAny(t, ['한도', '제한', 'limit', '하루', '일일'])) return null;
    final mins = _parseAllMinutes(t);
    if (mins.isEmpty) return null;
    final daily = mins.last;
    return BlockChatPlan(
      action: 'youtube_limit',
      dailyMinutes: daily,
      limitPlatform: 'youtube',
      reply: 'Isle 유튜브 일일 한도를 ${daily}분으로 설정합니다.',
    );
  }

  static BlockChatPlan? _parseAppSessionLimit(String t) {
    if (!_hasAny(t, ['인스타', 'instagram', '틱톡', 'tiktok'])) return null;
    final mins = _parseAllMinutes(t);
    if (mins.length < 2) return null;

    final appId = _hasAny(t, ['틱톡', 'tiktok']) ? 'tiktok' : 'instagram';
    final session = mins[0];
    final cooldown = mins.length >= 2 ? mins[1] : 10;
    final daily = mins.length >= 3
        ? mins[2]
        : (_hasAny(t, ['하루', '총', '일일']) ? mins.last : session + cooldown);

    return BlockChatPlan(
      action: 'app_session_limit',
      appId: appId,
      dailyMinutes: daily,
      sessionMinutes: session,
      cooldownMinutes: cooldown,
      scheduleName: appId == 'tiktok' ? '틱톡 세션 (AI)' : '인스타 세션 (AI)',
      reply: '$appId — 하루 $daily분, ${session}분 쓰고 ${cooldown}분 쉬기',
    );
  }

  static String? _extractNoMoreKeyword(String raw, String t) {
    if (!_hasAny(t, ['더이상', '더 이상', '그만'])) return null;
    final m = RegExp(r'더\s*이상\s+(.+?)\s*(영상|비디오|콘텐츠|보고|블락|차단|숨김)')
        .firstMatch(raw);
    var kw = m?.group(1)?.trim();
    if (kw == null || kw.length < 2) return null;
    kw = kw.replaceAll(RegExp(r'(유튜브|youtube)\s*$'), '').trim();
    return kw.length >= 2 ? kw : null;
  }

  static String? _extractYoutubeKeyword(String raw, String t) {
    if (_looksLikeSchedule(t)) return null;
    final m = RegExp(r'(.+?)\s*유튜브.*(블락|차단|숨김|숨기|block)', caseSensitive: false)
        .firstMatch(raw);
    final kw = m?.group(1)?.trim();
    if (kw == null || kw.length < 2 || kw.length > 24) return null;
    if (_hasAny(kw.toLowerCase(), ['내', 'isle', '이젤', '이슬', '매일', '아침'])) return null;
    return kw;
  }

  static List<int> _parseAllMinutes(String t) {
    return RegExp(r'(\d+)\s*분')
        .allMatches(t)
        .map((m) => int.tryParse(m.group(1)!) ?? 0)
        .where((n) => n > 0 && n <= 480)
        .toList();
  }

  static bool _hasAny(String t, List<String> needles) {
    for (final n in needles) {
      if (t.contains(n.toLowerCase())) return true;
    }
    return false;
  }

  static String? _extractQuoted(String raw) {
    final m = RegExp(r'[「『"]([^」』"]+)[」』"]').firstMatch(raw);
    return m?.group(1)?.trim();
  }

  /// 「10시30분」「10:30」「10시」
  static (int, int)? _parseEndTime(String t) {
    final hm = RegExp(r'(\d{1,2})\s*시\s*(\d{1,2})\s*분').firstMatch(t);
    if (hm != null) {
      final h = int.tryParse(hm.group(1)!);
      final m = int.tryParse(hm.group(2)!);
      if (h != null && h >= 0 && h <= 23 && m != null && m >= 0 && m <= 59) {
        return (h, m);
      }
    }
    final colon = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(t);
    if (colon != null) {
      final h = int.tryParse(colon.group(1)!);
      final m = int.tryParse(colon.group(2)!);
      if (h != null && h >= 0 && h <= 23 && m != null && m >= 0 && m <= 59) {
        return (h, m);
      }
    }
    final hOnly = RegExp(r'(\d{1,2})\s*시').firstMatch(t);
    if (hOnly != null) {
      final h = int.tryParse(hOnly.group(1)!);
      if (h != null && h >= 1 && h <= 23) return (h, 0);
    }
    return null;
  }

  static String? _extractBeforeBlock(String t) {
    if (_looksLikeSchedule(t)) return null;
    for (final sep in ['블락', '차단', '숨김', '숨기']) {
      final i = t.indexOf(sep);
      if (i > 0) {
        final before = t.substring(0, i).trim();
        if (before.length >= 2 && before.length <= 24) return before;
      }
    }
    return null;
  }
}
