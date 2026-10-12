import 'block_chat_models.dart';
import 'block_chat_persona_scenarios.dart';

/// 파싱된 [BlockChatPlan]을 적용 **전에** 사람이 읽을 수 있게 설명한다.
///
/// 부작용 없음(저장·OS 호출 0). 챗 화면에서 "이렇게 바꿀게요 → 확인" 카드를
/// 그릴 때 쓴다. 실제 적용은 사용자가 확인을 누른 뒤 [BlockChatExecutor]가 한다.
class BlockChatPreview {
  BlockChatPreview._();

  /// 확인 카드가 필요 없는(=정보성) 액션. 바로 답만 보여준다.
  /// focus_mode_ask — 집중 모드 트리거 직후 "뭘 막을까요?" 되묻는 메시지
  /// (cage 2026-07-13 이식). explain과 마찬가지로 확인 카드 없이 답변만
  /// 보여주고, 사용자의 다음 채팅이 곧 답변이 된다.
  static bool isInfoOnly(String action) =>
      action == 'explain' || action == 'unknown' || action == 'focus_mode_ask';

  static String headline(BlockChatPlan plan) {
    switch (plan.action) {
      case 'morning_schedule':
        return '아침 차단 스케줄 만들기';
      case 'allow_window':
        return '허용 시간대 만들기';
      case 'night_schedule':
        return '야간 차단 스케줄 만들기';
      case 'youtube_limit':
        return '유튜브 하루 한도';
      case 'youtube_budget':
        return '유튜브 나눠 쓰기';
      case 'usage_budget':
        return '${_targetKo(plan)} 나눠 쓰기';
      case 'platform_limit':
        return '${_platformKo(plan.limitPlatform)} 하루 한도';
      case 'app_session_limit':
        return '앱 세션 한도';
      case 'music_foreground_limit':
        return '음악·재생 시간 한도';
      case 'add_keyword':
        return '키워드 차단';
      case 'remove_keyword':
        return '키워드 차단 해제';
      case 'block_channel':
        return '채널 차단';
      case 'block_website':
        return '웹사이트 차단';
      case 'block_url':
        return 'URL 차단';
      case 'remove_url':
        return 'URL 차단 해제';
      case 'relax_block':
        return '차단 지금 풀기';
      case 'remove_schedule':
        return '스케줄 해제';
      case 'rename_schedule':
        return '스케줄 이름 변경';
      case 'update_schedule_time':
        return '스케줄 시간 변경';
      case 'add_schedule_days':
        return '스케줄 요일 추가';
      case 'remove_schedule_days':
        return '스케줄 요일 제거';
      case 'toggle_shorts':
        return (plan.toggleOn ?? true) ? '쇼츠 숨기기' : '쇼츠 다시 보이기';
      case 'toggle_reels':
        return (plan.toggleOn ?? true) ? '릴스 숨기기' : '릴스 다시 보이기';
      case 'toggle_reels_guard':
        return (plan.toggleOn ?? true) ? '릴스 둠스크롤 멈춤 켜기' : '릴스 둠스크롤 멈춤 끄기';
      case 'safari_pause':
        return 'Safari 잠깐 풀기';
      case 'morning_habit_pack':
        return '아침 습관 패키지';
      case 'persona_bundle':
        final p = BlockChatPersonaScenarios.byId(plan.personaId ?? '');
        return p != null ? '${p.persona} 맞춤 차단' : '맞춤 차단 패키지';
      case 'set_default_lock_cooldown':
        return '타임락 기본값 변경';
      case 'quick_block_now':
        return '지금부터 N시간 차단';
      case 'study_mode':
        return '공부 모드';
      case 'explain_status':
        return '차단 현황 조회';
      default:
        return '설정 적용';
    }
  }

  /// 적용될 내용 불릿. 비어 있으면 헤드라인만 보여준다.
  static List<String> bullets(BlockChatPlan plan) {
    final out = <String>[];
    switch (plan.action) {
      case 'morning_schedule':
        out.add(
            '${_daysKo(plan.days)} 00:00–${_hm(plan.endHour, plan.endMinute)} 차단');
        out.add(plan.blockSafariNote
            ? '대상: Isle 유튜브 · Safari·웹 · 앱(Screen Time 필요)'
            : '대상: Isle 유튜브');
        out.add('기본: 같은 아침 스케줄이 있으면 지우지 않고 시간·대상만 갱신');
        out.add('옵션: 「기존 유지하고 새로 만들기」 또는 「기존 끄고 새로 리셋」');
        out.add('타임락 켜짐 — 해제는 대기 시간 후');
      case 'allow_window':
        final sh = plan.startHour ?? 15;
        final sm = plan.startMinute ?? 0;
        out.add(
            '${_daysKo(plan.days)} ${_hm(sh, sm)}–${_hm(plan.endHour, plan.endMinute)} 동안 허용');
        out.add('그 외 시간에는 Isle 유튜브 차단');
        out.add('타임락 켜짐 — 해제는 대기 시간 후');
      case 'night_schedule':
        final sh = plan.startHour ?? 21;
        final sm = plan.startMinute ?? 0;
        out.add(
            '${_daysKo(plan.days)} ${_hm(sh, sm)}–${_hm(plan.endHour, plan.endMinute)} 차단');
        // 2026-07-11 디자인 리뷰 시뮬레이션에서 발견(Cage에서 먼저 발견 후 이식) —
        // 대상 앱을 아예 안 보여줘서 "카카오톡 차단해줘"의 확인 카드가 어느
        // 앱인지 안 나오던 실제 갭.
        out.add(plan.blockSafariNote
            ? '대상: 브라우저(Safari)'
            : '대상: ${_targetKo(plan)}');
        out.add('기본: 같은 야간 스케줄이 있으면 지우지 않고 시간·대상만 갱신');
        out.add('옵션: 「기존 유지하고 새로 만들기」 또는 「기존 끄고 새로 리셋」');
      case 'youtube_limit':
        if (plan.dailyMinutes != null) out.add('하루 ${plan.dailyMinutes}분');
        out.add('대상: Isle 유튜브');
        if (plan.suggestTimelock) out.add('한도 변경에 타임락 안내');
      case 'youtube_budget':
      case 'usage_budget':
        if (plan.startHour != null) {
          out.add(
              '${_hm(plan.startHour!, plan.startMinute ?? 0)}–${_hm(plan.endHour, plan.endMinute)} 적용');
        }
        if (plan.dailyMinutes != null) out.add('하루 총량 ${plan.dailyMinutes}분');
        if (plan.sessionMinutes != null)
          out.add('한 번에 ${plan.sessionMinutes}분');
        out.add('${plan.windowMinutes ?? 60}분 뒤 다시 충전');
        out.add('다 쓰면 ${plan.cooldownMinutes ?? plan.windowMinutes ?? 60}분 잠금');
      case 'platform_limit':
        if (plan.dailyMinutes != null) out.add('하루 ${plan.dailyMinutes}분');
        out.add('대상: ${_platformKo(plan.limitPlatform)}');
      case 'app_session_limit':
        if (plan.sessionMinutes != null) out.add('세션 ${plan.sessionMinutes}분');
        if (plan.cooldownMinutes != null)
          out.add('쿨다운 ${plan.cooldownMinutes}분');
      // 2026-07-11 전체 감사에서 발견 — 실행기(`_musicForegroundLimit`)는 실제로
      // sessionMinutes/windowMinutes(기본 [REDACTED])를 적용하는데 여기선 엉뚱하게
      // dailyMinutes를 참조해서, dailyMinutes가 파싱 안 됐을 땐 카드가 완전히
      // 비었고 어쩌다 있어도 실제 적용값과 다른 숫자를 보여주고 있었다.
      case 'music_foreground_limit':
        out.add(
            '${plan.windowMinutes ?? 60}분마다 ${plan.sessionMinutes ?? 10}분 한도');
      case 'add_keyword':
      case 'remove_keyword':
        final kw = plan.keyword ?? plan.removeKeyword;
        if (kw != null) out.add('키워드: 「$kw」');
      case 'block_channel':
        if (plan.channelName != null) out.add('채널: 「${plan.channelName}」');
      case 'block_website':
        if (plan.websiteDomain != null) out.add('도메인: ${plan.websiteDomain}');
      case 'block_url':
      case 'remove_url':
        final u = plan.removeUrl;
        if (u != null) out.add('URL: ${_shortUrl(u)}');
      case 'relax_block':
        out.add('대상: ${_relaxKo(plan.relaxTarget)}');
        out.add('지금 즉시 해제 (일회성)');
      case 'remove_schedule':
        final q = plan.scheduleQuery ?? plan.removeScheduleQuery;
        if (q != null && q.isNotEmpty) out.add('스케줄: 「$q」');
        out.add('타임락 켜져 있으면 대기 후 자동 해제');
      case 'rename_schedule':
        if (plan.scheduleNewName != null)
          out.add('새 이름: 「${plan.scheduleNewName}」');
      case 'update_schedule_time':
        out.add('새 종료: ${_hm(plan.endHour, plan.endMinute)}');
      case 'add_schedule_days':
      case 'remove_schedule_days':
        out.add('요일: ${_daysKo(plan.days)}');
      case 'safari_pause':
        if (plan.pauseMinutes != null)
          out.add('${plan.pauseMinutes}분 후 자동 재잠금');
      case 'morning_habit_pack':
        out.add(
            '${_daysKo(plan.days)} 00:00–${_hm(plan.endHour, plan.endMinute)} 아침 차단');
        if (plan.dailyMinutes != null)
          out.add('Isle 유튜브 하루 ${plan.dailyMinutes}분');
        if (plan.sessionMinutes != null) {
          out.add('YouTube 앱은 ${plan.sessionMinutes}분 단위로 끊기');
        }
        out.add('적용 후 카드에서 타임락 설정으로 이동 가능');
      case 'persona_bundle':
        final p = BlockChatPersonaScenarios.byId(plan.personaId ?? '');
        if (p != null) out.add('여러 차단·한도를 한 번에 적용');
      case 'set_default_lock_cooldown':
        out.add('앞으로 새로 만드는 스케줄에 적용 (최소 15분)');
        out.add('이미 있는 스케줄의 잠금 시간은 그대로 유지');
      // Cage와 같은 패턴의 실사용 버그(2026-07-11, 사진 제보) — explain_status는
      // headline()엔 있지만 여기 case가 없어서 확인 카드가 완전히 빈 채로 뜬다.
      case 'explain_status':
        out.add('지금 설정·남은 시간을 조회해서 보여드려요');
        if (plan.limitPlatform != null)
          out.add('대상: ${_platformKo(plan.limitPlatform)}');
      // 2026-07-11 전체 감사에서 발견 — quick_block_now는 headline()엔 있지만
      // bullets()에 case가 없어 몇 시간·어느 앱을 지금부터 막는지 확인 전에
      // 전혀 안 보였다(explain_status와 같은 클래스의 갭, 더 심각 — 파라미터가
      // 있는 실제 액션이라 확인 없이는 사용자가 뭘 누르는지 모름).
      case 'quick_block_now':
        // 24시간으로 표시가 고정돼 있으면 "3일간" 요청도 카드엔 "24시간"으로
        // 거짓 표시된다(2026-07-13, executor 상한을 30일로 늘린 것과 짝).
        final hours = ((plan.windowMinutes ?? 180) / 60).ceil().clamp(1, 24 * 30);
        final durationLabel =
            hours % 24 == 0 ? '${hours ~/ 24}일' : '$hours시간';
        out.add('지금부터 $durationLabel 동안 차단');
        out.add('대상: ${_targetKo(plan)}');
      case 'study_mode':
        final hours = ((plan.windowMinutes ?? 360) / 60).ceil().clamp(1, 24 * 30);
        out.add('${hours}시간 동안 유지');
        out.add('브라우저 차단 · 유튜브 제한 · 포모도로 동기화');
      case 'toggle_shorts':
        out.add((plan.toggleOn ?? true)
            ? 'YouTube Shorts 탭·피드에서 숨김'
            : 'YouTube Shorts 다시 보이게 전환');
      case 'toggle_reels':
        out.add((plan.toggleOn ?? true)
            ? 'Instagram Reels 탭에서 숨김'
            : 'Instagram Reels 다시 보이게 전환');
      case 'toggle_reels_guard':
        out.add((plan.toggleOn ?? true)
            ? '릴스를 일정량 스크롤하면 멈추라고 알림'
            : '릴스 스크롤 멈춤 알림 끔');
      default:
        break;
    }
    return out;
  }

  // ── helpers ────────────────────────────────────────────────────────────
  static String _hm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  static String _daysKo(List<int> days) {
    final s = days.toSet();
    if (s.length >= 7) return '매일';
    if (s.length == 5 && s.containsAll({0, 1, 2, 3, 4})) return '평일';
    if (s.length == 2 && s.containsAll({5, 6})) return '주말';
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    final sorted = days.where((d) => d >= 0 && d <= 6).toList()..sort();
    if (sorted.isEmpty) return '매일';
    return '${sorted.map((d) => names[d]).join('·')}요일';
  }

  static String _platformKo(String? p) {
    switch ((p ?? 'youtube').toLowerCase()) {
      case 'instagram':
        return 'Instagram';
      case 'app:kakao':
      case 'kakao':
      case 'kakaotalk':
        return '카카오톡';
      case 'safari':
        return 'Safari·웹';
      case 'app':
        return '앱';
      // Cage와 같은 클래스의 버그(2026-07-11) — youtube_music이 없어서
      // default로 새어 플레인 유튜브와 구분이 안 되던 문제.
      case 'youtube_music':
        return 'YouTube Music';
      case 'youtube':
      default:
        return '유튜브';
    }
  }

  static String _targetKo(BlockChatPlan plan) {
    // 2026-07-11 비주얼 리뷰 시뮬레이션에서 발견 — 실제 파서는 "카카오톡
    // 차단해줘" 같은 요청에서 appId만 채우고 limitPlatform은 null로 두는데,
    // 여기선 limitPlatform=='app'일 때만 appId를 봤다. 그래서 실제 카카오톡
    // night_schedule 확인 카드가 "대상: 유튜브"로 완전히 잘못 나오고 있었다.
    final appId = (plan.appId ?? '').toLowerCase();
    if (appId == 'kakao' || appId == 'kakaotalk') return '카카오톡';
    if (appId == 'tiktok') return 'TikTok';
    if (appId == 'youtube_music') return 'YouTube Music';
    if ((plan.limitPlatform ?? '').toLowerCase() == 'app') {
      return _platformKo(plan.appId ?? 'app');
    }
    return _platformKo(plan.limitPlatform);
  }

  static String _relaxKo(String? target) {
    switch ((target ?? 'youtube').toLowerCase()) {
      case 'safari':
        return 'Safari·웹';
      case 'instagram':
        return 'Instagram';
      case 'all':
        return '전체 차단';
      case 'youtube':
      default:
        return '유튜브';
    }
  }

  static String _shortUrl(String u) =>
      u.length <= 48 ? u : '${u.substring(0, 45)}…';
}
