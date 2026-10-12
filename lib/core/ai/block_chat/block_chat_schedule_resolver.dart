import '../../block_schedule/block_schedule_store.dart';
import '../../block_schedule/models/block_schedule.dart';
import '../../block_schedule/models/schedule_slot.dart';
import '../../block_schedule/quick_block_service.dart';
import '../../block_schedule/schedule_active_service.dart';

/// AI 챗 — 정확한 스케줄명 없이 후보 찾기
class BlockChatScheduleMatch {
  const BlockChatScheduleMatch({
    required this.schedule,
    required this.matchedBecause,
    this.alternates = const [],
  });

  final BlockSchedule schedule;
  final String matchedBecause;
  final List<String> alternates;
}

class BlockChatScheduleResolver {
  BlockChatScheduleResolver._();

  static const _tagKeywords = <String, List<String>>{
    'safari': ['safari', '사파리', '웹', '브라우저'],
    'youtube': ['youtube', '유튜브', 'yt', '뮤직', 'music', '영상'],
    'isle': ['isle', '이슬', '이젤', '인앱', '앱 안'],
    'instagram': ['instagram', '인스타', 'insta'],
    'tiktok': ['tiktok', '틱톡'],
    'morning': ['아침', 'morning', '기상', '출근'],
    'evening': ['저녁', '야간', '밤', 'night', 'sns'],
    'ai': ['(ai)', 'ai)', 'ai ', '챗', '만든'],
  };

  /// [rawQuery] 비어 있으면 활성 → 최근 AI → 첫 enabled 순
  static BlockChatScheduleMatch? resolve(String? rawQuery) {
    final all = BlockScheduleStore.loadAll()
        .where((s) => s.id != QuickBlockService.presetScheduleId)
        .toList();
    if (all.isEmpty) return null;

    final q = rawQuery?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return _resolveWithoutQuery(all);

    final scored = <_Scored>[];
    for (final s in all) {
      final score = _score(s, q);
      if (score > 0) scored.add(_Scored(s, score));
    }
    if (scored.isEmpty) {
      final fallback = _resolveWithoutQuery(all);
      if (fallback == null) return null;
      return BlockChatScheduleMatch(
        schedule: fallback.schedule,
        matchedBecause: '이름이 비슷한 게 없어서 ${fallback.matchedBecause}',
        alternates: fallback.alternates,
      );
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final best = scored.first;
    final alts = scored
        .skip(1)
        .where((e) => best.score - e.score <= 25)
        .map((e) => e.schedule.name)
        .take(3)
        .toList();
    return BlockChatScheduleMatch(
      schedule: best.schedule,
      matchedBecause: _because(best.schedule, q, best.score),
      alternates: alts,
    );
  }

  static BlockChatScheduleMatch? _resolveWithoutQuery(List<BlockSchedule> all) {
    final active = ScheduleActiveService.activeSchedulesNow();
    if (active.length == 1) {
      return BlockChatScheduleMatch(
        schedule: active.first,
        matchedBecause: '지금 활성인 스케줄',
      );
    }
    if (active.length > 1) {
      return BlockChatScheduleMatch(
        schedule: active.first,
        matchedBecause: '지금 활성인 스케줄 중 첫 번째',
        alternates: active.skip(1).map((s) => s.name).toList(),
      );
    }

    final enabled = all.where((s) => s.enabled).toList();
    final aiRecent = enabled.where((s) => s.name.toLowerCase().contains('ai')).toList();
    if (aiRecent.length == 1) {
      return BlockChatScheduleMatch(
        schedule: aiRecent.first,
        matchedBecause: '최근 AI 챗으로 만든 스케줄',
      );
    }

    if (enabled.length == 1) {
      return BlockChatScheduleMatch(
        schedule: enabled.first,
        matchedBecause: '켜져 있는 유일한 스케줄',
      );
    }
    if (enabled.isNotEmpty) {
      return BlockChatScheduleMatch(
        schedule: enabled.first,
        matchedBecause: '켜져 있는 스케줄 중 첫 번째',
        alternates: enabled.skip(1).map((s) => s.name).toList(),
      );
    }

    return BlockChatScheduleMatch(
      schedule: all.first,
      matchedBecause: '등록된 스케줄 중 첫 번째',
      alternates: all.skip(1).map((s) => s.name).toList(),
    );
  }

  static int _score(BlockSchedule s, String q) {
    var score = 0;
    final name = s.name.toLowerCase();

    if (name.contains(q)) score += 120;
    if (q.contains(name) && name.length >= 3) score += 80;

    for (final token in q.split(RegExp(r'[\s,·]+'))) {
      if (token.length >= 2 && name.contains(token)) score += 35;
    }

    for (final entry in _tagKeywords.entries) {
      if (!_queryHasTag(q, entry.value)) continue;
      if (_scheduleHasTag(s, entry.key, name)) score += 55;
    }

    if (_queryHasTag(q, ['지금', '활성', '켜진', '진행']) &&
        ScheduleActiveService.isScheduleActiveNow(s)) {
      score += 45;
    }
    if (_queryHasTag(q, ['최근', '방금', '아까', '어제', '만든', 'ai'])) {
      if (name.contains('ai') || name.contains('(ai)')) score += 50;
    }
    if (s.enabled) score += 8;
    if (ScheduleActiveService.isScheduleActiveNow(s)) score += 12;

    return score;
  }

  static bool _queryHasTag(String q, List<String> needles) {
    for (final n in needles) {
      if (q.contains(n)) return true;
    }
    return false;
  }

  static bool _scheduleHasTag(BlockSchedule s, String tag, String nameLower) {
    switch (tag) {
      case 'safari':
        return nameLower.contains('safari') ||
            nameLower.contains('사파리') ||
            s.blockIsleInApp;
      case 'youtube':
        return nameLower.contains('유튜브') ||
            nameLower.contains('youtube') ||
            nameLower.contains('뮤직') ||
            s.domains.any((d) => d.contains('youtube'));
      case 'isle':
        return nameLower.contains('isle') ||
            nameLower.contains('이슬') ||
            s.blockIsleInApp;
      case 'instagram':
        return nameLower.contains('인스타');
      case 'tiktok':
        return nameLower.contains('틱톡') || nameLower.contains('tiktok');
      case 'morning':
        return nameLower.contains('아침');
      case 'evening':
        return nameLower.contains('야간') ||
            nameLower.contains('저녁') ||
            nameLower.contains('sns');
      case 'ai':
        return nameLower.contains('ai');
      default:
        return false;
    }
  }

  static String _because(BlockSchedule s, String q, int score) {
    if (s.name.toLowerCase().contains(q)) return '이름에 「$q」 포함';
    if (score >= 100) return '키워드·내용이 가장 잘 맞음';
    return '비슷한 스케줄로 추정';
  }

  /// 아침형(0시~N시) 스케줄의 공통 종료 분
  static int? morningEndMinute(BlockSchedule s) {
    final morning = s.slots.where((sl) => sl.startMinute == 0).toList();
    if (morning.isEmpty) return null;
    return morning.map((sl) => sl.endMinute).reduce((a, b) => a > b ? a : b);
  }

  static List<ScheduleSlot> replaceMorningEnd({
    required BlockSchedule schedule,
    required int endMinute,
    List<int>? days,
  }) {
    final end = endMinute.clamp(1, 1439);
    final daySet = days?.map((d) => d.clamp(0, 6)).toSet();
    final kept = schedule.slots.where((sl) {
      if (sl.startMinute != 0) return true;
      if (daySet == null) return false;
      return !daySet.contains(sl.day);
    }).toList();
    final targetDays = daySet ?? schedule.slots.map((sl) => sl.day).toSet();
    if (targetDays.isEmpty) {
      for (var d = 0; d < 7; d++) {
        kept.add(ScheduleSlot(day: d, startMinute: 0, endMinute: end));
      }
    } else {
      for (final d in targetDays) {
        kept.add(ScheduleSlot(day: d, startMinute: 0, endMinute: end));
      }
    }
    return kept;
  }

  static List<ScheduleSlot> addMorningDays({
    required BlockSchedule schedule,
    required List<int> days,
    required int endMinute,
  }) {
    final end = endMinute.clamp(1, 1439);
    final existing = List<ScheduleSlot>.from(schedule.slots);
    final have = existing.map((s) => s.day).toSet();
    for (final d in days.map((x) => x.clamp(0, 6))) {
      if (have.contains(d)) continue;
      existing.add(ScheduleSlot(day: d, startMinute: 0, endMinute: end));
    }
    return existing;
  }

  static List<ScheduleSlot> removeDays({
    required BlockSchedule schedule,
    required List<int> days,
  }) {
    final remove = days.map((d) => d.clamp(0, 6)).toSet();
    return schedule.slots.where((sl) => !remove.contains(sl.day)).toList();
  }

  static String formatScheduleHint(BlockChatScheduleMatch match) {
    final buf = StringBuffer('「${match.schedule.name}」 (${match.matchedBecause})');
    if (match.alternates.isNotEmpty) {
      buf.write('\n비슷한 후보: ${match.alternates.join(' · ')}');
    }
    return buf.toString();
  }
}

class _Scored {
  const _Scored(this.schedule, this.score);
  final BlockSchedule schedule;
  final int score;
}
