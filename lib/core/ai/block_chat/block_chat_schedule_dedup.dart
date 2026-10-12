import '../../block_schedule/block_schedule_store.dart';
import '../../block_schedule/models/block_schedule.dart';
import '../../block_schedule/schedule_app_targets_store.dart';

/// AI 챗 스케줄 생성 시 이름·범위 겹침으로 인한 중복·오동작 방지
class BlockChatScheduleDedup {
  BlockChatScheduleDedup._();

  /// 안전 라인 스케줄(`isSafetyBaseline`)은 fuzzy dedup 후보에서 항상 제외한다
  /// — 이름/overnight 패턴/타깃 겹침만 보고 매칭하면, 안전 라인이 미리 걸어둔
  /// 21:30~10:00 완전 차단·유튜브 시간당 10분 스케줄을 무관한 챗 요청이
  /// "기존 스케줄"로 오인해 재사용(=덮어쓰기)해버릴 수 있다 — 안전 라인은
  /// 오직 설정 화면의 스위치+타임락으로만 바뀌어야 하므로(2026-07-16
  /// 사용자 요청), 챗 쪽 dedup 경로에선 아예 안 보이게 한다.
  static List<BlockSchedule> _dedupCandidates() =>
      BlockScheduleStore.loadAll().where((s) => !s.isSafetyBaseline).toList();

  static BlockSchedule? findExactName(String? name) {
    final q = name?.trim();
    if (q == null || q.isEmpty) return null;
    for (final s in _dedupCandidates()) {
      if (s.name == q) return s;
    }
    return null;
  }

  /// 아침 0시~N분 Isle 유튜브 전용 스케줄
  static BlockSchedule? findIsleYoutubeMorning({String? preferredName}) {
    final byName = findExactName(preferredName);
    if (byName != null) return byName;

    for (final s in _dedupCandidates()) {
      if (!_isMorningSlotPattern(s)) continue;
      final entries = ScheduleAppTargetsStore.loadForSchedule(s.id);
      final blocksIsleYt = entries.any(
        (e) => e.targetId == 'isle_youtube' && e.blockInSlot,
      );
      if (blocksIsleYt && !s.blockIsleInApp) return s;
    }
    return null;
  }

  /// Safari·Isle 웹 아침 스케줄 (blockIsleInApp 또는 safari 타깃)
  static BlockSchedule? findSafariMorning({String? preferredName}) {
    final byName = findExactName(preferredName);
    if (byName != null) return byName;

    for (final s in _dedupCandidates()) {
      if (s.blockIsleInApp && _isMorningSlotPattern(s)) return s;
      final n = s.name.toLowerCase();
      if (_isMorningSlotPattern(s) &&
          (n.contains('safari') || n.contains('아침 safari'))) {
        return s;
      }
    }
    return null;
  }

  /// SNS 야간 (21:00–07:00 등 overnight 슬롯)
  ///
  /// [targetIds]를 주면 "이름·overnight 패턴이 비슷하다"만으로 매칭하지 않고
  /// **이미 그 앱을 대상으로 하는 스케줄만** 재사용한다. 예전엔 앱 구분 없이
  /// "야간스러운 스케줄이면 아무거나" 매칭해서, 카카오톡 야간 리필이 이미 있는데
  /// 이름이 다른 틱톡 요청이 들어오면 정확한 이름 매치 실패 후 카카오톡 스케줄을
  /// 가로채 재사용해버렸다 — 이름은 여전히 "카카오톡..."인데 틱톡 제한까지 같이
  /// 걸리는 co-mingle 버그(2026-07-06, cage에서 발견 후 이식).
  static BlockSchedule? findNightSns({
    String? preferredName,
    List<String>? targetIds,
  }) {
    final byName = findExactName(preferredName);
    if (byName != null) return byName;

    for (final s in _dedupCandidates()) {
      final n = s.name.toLowerCase();
      final looksNight = n.contains('야간') ||
          n.contains('sns 야간') ||
          n.contains('night') ||
          s.slots.any((sl) => sl.startMinute > sl.endMinute);
      if (!looksNight) continue;
      if (targetIds == null || targetIds.isEmpty) return s;
      final entries = ScheduleAppTargetsStore.loadForSchedule(s.id);
      final alreadyTargetsSameApp = entries.any(
        (e) =>
            targetIds.contains(e.targetId) &&
            (e.blockInSlot || e.limitEnabled),
      );
      if (alreadyTargetsSameApp) return s;
    }
    return null;
  }

  /// AI 챗이 만든 habit / music / session 패키지 — 이름 접미사 (AI)
  static BlockSchedule? findAiNamedPack(String nameHint) {
    final hint = nameHint.toLowerCase();
    BlockSchedule? best;
    for (final s in _dedupCandidates()) {
      final n = s.name.toLowerCase();
      if (!n.contains('(ai)') && !n.contains('ai)')) continue;
      if (hint.isNotEmpty && n.contains(hint)) return s;
      best ??= s;
    }
    return best;
  }

  static bool _isMorningSlotPattern(BlockSchedule s) {
    if (s.slots.isEmpty) return false;
    return s.slots.every((sl) => sl.startMinute == 0 && sl.endMinute < 1440);
  }
}
