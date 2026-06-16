import 'package:flutter/material.dart';

import '../block_schedule/models/schedule_enforcement_mode.dart';

/// Schedule + optional app-restriction copy.
///
/// **Product language (team):**
/// - Primary: schedule / time windows (일정·スケジュール·Schedule).
/// - Secondary: app lock / Screen Time shield (앱 잠금 — never "차단 시간" alone in KO).
/// - Main feed / YouTube stay Korean-first until localized separately.
class ScheduleStrings {
  final String lang;
  const ScheduleStrings(this.lang);

  static ScheduleStrings of(BuildContext context) =>
      ScheduleStrings(Localizations.localeOf(context).languageCode);

  String t(String key, {Map<String, String>? args}) {
    final m = _tables[lang] ?? _tables['en']!;
    var v = m[key] ?? _tables['en']![key] ?? key;
    args?.forEach((k, val) => v = v.replaceAll('{$k}', val));
    return v;
  }

  String modeLabel(ScheduleEnforcementMode mode) => t(switch (mode) {
        ScheduleEnforcementMode.fullBlock => 'mode_full_label',
        ScheduleEnforcementMode.limitInSlot => 'mode_limit_label',
        ScheduleEnforcementMode.blockInSlotLimitOutside => 'mode_combo_label',
      });

  String modeSubtitle(ScheduleEnforcementMode mode) => t(switch (mode) {
        ScheduleEnforcementMode.fullBlock => 'mode_full_sub',
        ScheduleEnforcementMode.limitInSlot => 'mode_limit_sub',
        ScheduleEnforcementMode.blockInSlotLimitOutside => 'mode_combo_sub',
      });

  String modeScenario(ScheduleEnforcementMode mode) => t(switch (mode) {
        ScheduleEnforcementMode.fullBlock => 'mode_full_scenario',
        ScheduleEnforcementMode.limitInSlot => 'mode_limit_scenario',
        ScheduleEnforcementMode.blockInSlotLimitOutside => 'mode_combo_scenario',
      });

  static const _tables = <String, Map<String, String>>{
    'ko': _ko,
    'en': _en,
    'ja': _ja,
    'zh': _zh,
    'he': _he,
  };
}

const _ko = <String, String>{
  'hub_title': '앱 스케줄',
  'hub_intro': '스케줄을 눌러 ①언제 ②어떻게 ③무엇을 막을지 정하세요.',
  'hub_lock_note': '④ 설정 잠금 = 시간표 수정만 어렵게 (앱 차단 아님)',
  'hub_important': '앱만 고르면 동작하지 않아요. ① 일정 시간대가 필요합니다.',
  'edit_help_title': '이 화면 사용법',
  'edit_help_body': '① 언제 — 요일·시간\n'
      '② 방식 — 잠금 / N분만 / 둘 다\n'
      '③ 대상 — Isle·iPhone 앱 체크\n'
      '④ 설정 잠금 — 선택 (앱 차단과 별개)',
  'master_on': '스케줄 사용',
  'master_off_sub': '꺼 두면 일정·알림이 모두 적용되지 않아요',
  'notif_title': '스케줄 시작·종료 알림',
  'notif_on': '일정이 켜지거나 꺼질 때 알림 (7일 앞까지 예약)',
  'notif_need_master': '스케줄을 켜야 알림이 예약돼요',
  'notif_permission': '알림 권한이 필요해요. 설정 → Isle → 알림에서 허용해 주세요.',
  'schedule_list': '스케줄 목록',
  'volt_resume': '앱이 꺼져 있을 때는 iOS가 백그라운드 타이머를 허용하지 않습니다. '
      '다시 열면 타임스탬프로 경계를 맞춥니다.',
  'lock_master_blocked': '설정 잠금이 켜진 활성 스케줄이 있어요. '
      '스케줄 편집 ④에서 잠금 해제 카운트다운을 먼저 완료하세요.',
  'window_sheet_title': '일정 시간대',
  'window_sheet_desc': '적용할 요일과 「시작 → 종료」 시각을 정하세요. 시간대는 여러 개 추가할 수 있어요.',
  'window_empty': '아직 일정 시간대가 없어요',
  'window_add': '일정 시간대 추가',
  'window_edit': '시간대 편집',
  'picker_title': '제한 방식',
  'picker_sub': '일정이 켜진 동안의 동작',
  'scenario_heading': '예시',
  'edit_flow': '① 언제 → ② 방식 → ③ 대상 → ④ 설정 잠금(선택)',
  'step1_title': '언제',
  'step1_sub': '요일·시간. 다르면 시간대를 추가하세요.',
  'step2_title': '방식',
  'step2_sub': '',
  'step3_title': '막을 대상',
  'step3_sub': 'Isle 안 · iPhone 앱 · 시간 한도(선택)',
  'step4_title': '설정 잠금',
  'step4_sub': '시간표 수정만 어렵게 (앱 차단 아님)',
  'active_blocking': '지금 이 스케줄 적용 중',
  'active_blocking_locked': '적용 중 · 설정 잠금 — 해제 후 5분만 편집',
  'no_windows_yet': '아직 일정 시간대가 없어요. 시간대를 추가해야 이 스케줄이 동작합니다.',
  'schedule_name': '스케줄 이름',
  'schedule_enabled': '이 스케줄 사용',
  'save': '저장',
  'saving': '저장 중…',
  'pick_apps_shield': '앱 잠금 — Screen Time에서 선택',
  'pick_apps_limit': '시간 한도에 쓸 앱 (Screen Time)',
  'pick_apps_fallback': '비어 있으면 설정의 전역 앱 선택을 씁니다.',
  'shield_when_slot': '일정 시간이 켜지면 OS가 선택한 앱을 잠급니다.',
  'limit_when_slot': '슬롯 {when}에서 시간당 한도가 적용됩니다.',
  'active_now': '지금 활성 — OS에 즉시 반영됩니다.',
  'block_isle_in_app': 'Isle 앱 안에서도 제한',
  'block_isle_sub': '켜면 Isle WebView·인스타 등 앱 내 화면도 막힙니다. '
      '끄면 일정 시간에도 Isle 유튜브는 볼 수 있어요.',
  'check_step1': '① 일정 시간대',
  'check_step1_need': '일정 시간대를 최소 1개 추가하세요',
  'check_step1_ok': '슬롯 {n}개 설정됨',
  'check_step2': '② 앱 잠금 (선택)',
  'check_step2_need': 'Screen Time에서 잠글 앱을 선택하세요',
  'check_step2_ok': '앱 {apps}개 · 카테고리 {cats}개',
  'check_step2_optional': '현재 방식은 앱 잠금이 필수가 아니어서 선택사항',
  'check_footer': '',
  'ready': '설정 OK',
  'not_ready': '아직 필요한 항목',
  'limit_hint_full': '앱 잠금 모드에서는 슬롯 밖 한도가 필요 없어요. 방식을 바꾸면 여기서 설정할 수 있어요.',
  'mode_full_label': '일정 중 앱 잠금',
  'mode_full_sub': '선택한 앱 아이콘을 열 수 없음',
  'mode_limit_label': '일정 중 N분만',
  'mode_limit_sub': '잠금 없이 시간 한도만',
  'mode_combo_label': '일정 잠금 + 평소 N분',
  'mode_combo_sub': '일정엔 잠금, 나머지 시간은 한도',
  'mode_full_scenario': '9–12시: 인스타·틱톡 잠금. 12시 이후: 해제.',
  'mode_limit_scenario': '9–12시: 인스타 1시간당 8분. 잠금 없음.',
  'mode_combo_scenario': '9–12시: 잠금. 그 외: 1시간당 N분.',
  'overlay_title': '일정 시간 — Screen Time 확인',
  'overlay_body': '지금은 스케줄 일정 시간이에요.\n'
      '앱 잠금은 Screen Time 설정을 확인하세요.',
  'preset_name': '집중 일정',
  'schedule_empty_list': '스케줄이 없습니다. 아래에서 추가하세요.',
  'add_schedule': '스케줄 추가',
  'change_apps': '앱 잠금 변경',
  'active_chip': ' · 지금 활성',
  'slots_count': '{n}개 슬롯',
};

const _en = <String, String>{
  'hub_title': 'App schedules',
  'hub_intro': 'Tap a schedule: ① when ② how ③ what to limit.',
  'edit_help_title': 'How this screen works',
  'edit_help_body': '① When — days & times\n'
      '② How — lock / minutes / both\n'
      '③ Targets — Isle & iPhone apps\n'
      '④ Schedule lock — optional (not app blocking)',
  'active_blocking': 'This schedule is active now',
  'active_blocking_locked': 'Active · schedule lock — edit for 5 min after unlock',
  'hub_lock_note': '“Schedule lock” only protects your timetable from edits—not app blocking (step ④).',
  'hub_important': 'Picking apps alone is not enough. You need schedule windows for anything to run. '
      'Without windows, nothing is blocked 24/7—the schedule simply won’t apply.',
  'master_on': 'Use schedules',
  'master_off_sub': 'When off, windows and alerts won’t apply',
  'notif_title': 'Schedule start & end alerts',
  'notif_on': 'Notify when a window turns on or off (booked 7 days ahead)',
  'notif_need_master': 'Turn schedules on to book alerts',
  'notif_permission': 'Notifications are required. Allow them in Settings → Isle → Notifications.',
  'schedule_list': 'Your schedules',
  'volt_resume': 'iOS won’t run timers while the app is closed. Reopening syncs boundaries from timestamps.',
  'lock_master_blocked': 'An active schedule has schedule lock on. Finish the unlock countdown in step ④ first.',
  'window_sheet_title': 'Schedule windows',
  'window_sheet_desc': 'Choose days and a start → end time. You can add multiple windows.',
  'window_empty': 'No schedule windows yet',
  'window_add': 'Add schedule window',
  'window_edit': 'Edit windows',
  'picker_title': 'During scheduled times',
  'picker_sub': 'How apps behave in your windows. App lock is optional and secondary.',
  'scenario_heading': 'What happens?',
  'edit_flow': '① Windows → ② Restrict apps (optional) → ③ Time limits (optional) → ④ Schedule lock (optional)\n'
      'Schedule lock does not block apps.',
  'step1_title': 'When it runs (timetable)',
  'step1_sub': 'Set days, start, and duration. Add multiple windows if days differ.',
  'step2_title': 'Behavior in windows',
  'step2_sub': 'App lock / time only / both — timetable first, app rules second',
  'step3_title': 'Time limits (optional)',
  'step3_sub': 'Use “N minutes per hour” instead of a full lock. Registered separately in Screen Time.',
  'step4_title': 'Schedule lock (optional)',
  'step4_sub': 'Makes timetable edits harder. Separate from restricting apps.',
  'no_windows_yet': 'No windows yet. Add at least one for this schedule to work.',
  'schedule_name': 'Schedule name',
  'schedule_enabled': 'Enable this schedule',
  'save': 'Save',
  'saving': 'Saving…',
  'pick_apps_shield': 'Restrict apps — Screen Time picker',
  'pick_apps_limit': 'Apps for time limits (Screen Time)',
  'pick_apps_fallback': 'If empty, the global app selection in Settings is used.',
  'shield_when_slot': 'While a window is active, iOS locks the chosen apps.',
  'limit_when_slot': 'Per-hour limits apply {when} the window.',
  'active_now': 'Active now — syncing to Screen Time.',
  'block_isle_in_app': 'Also limit inside Isle',
  'block_isle_sub': 'Blocks Isle WebView and in-app browsers. When off, YouTube in Isle may still work during windows.',
  'check_step1': '① Schedule windows',
  'check_step1_need': 'Add at least one window',
  'check_step1_ok': '{n} window(s) set',
  'check_step2': '② Restrict apps (optional)',
  'check_step2_need': 'Pick apps to lock in Screen Time',
  'check_step2_ok': '{apps} apps · {cats} categories',
  'check_step2_optional': 'Current mode doesn’t require app lock',
  'check_footer': 'App picks alone aren’t enough—windows in step ① are required.',
  'ready': 'Ready to finish',
  'not_ready': 'Before you finish',
  'limit_hint_full': 'Full lock mode doesn’t need outside-window limits. Change behavior above to adjust.',
  'mode_full_label': 'Lock apps during window',
  'mode_full_sub': 'Chosen apps can’t open while the window is on. Strongest option.',
  'mode_limit_label': 'Allow N minutes per hour',
  'mode_limit_sub': 'No app lock—only a per-hour cap (e.g. 8 min).',
  'mode_combo_label': 'Lock in window + cap outside',
  'mode_combo_sub': 'Lock during windows; per-hour limit the rest of the day.',
  'mode_full_scenario': 'e.g. 9am–12pm focus →\n'
      '• Instagram/TikTok locked via Screen Time\n'
      '• Isle YouTube only if “Also limit inside Isle” is on\n'
      'After 12pm → no limits',
  'mode_limit_scenario': 'e.g. 9am–12pm →\n'
      '• Instagram up to 8 min/hour\n'
      '• No icon lock\n'
      'After 12pm → no limits',
  'mode_combo_scenario': 'e.g. 9am–12pm → app lock\n'
      'Other hours → N minutes per hour',
  'overlay_title': 'Scheduled time — check Screen Time',
  'overlay_body': 'You’re in an active schedule window.\n'
      'App restrictions are managed in Screen Time.',
  'preset_name': 'Focus schedule',
  'schedule_empty_list': 'No schedules yet. Add one below.',
  'add_schedule': 'Add schedule',
  'change_apps': 'Change app restrictions',
  'active_chip': ' · active now',
  'slots_count': '{n} windows',
};

const _ja = <String, String>{
  'hub_title': 'アプリスケジュール',
  'hub_intro': '① スケジュール時間帯 → ② アプリ制限（任意） → ③ 時間上限（任意）。各項目をタップして設定。',
  'hub_lock_note': '「設定ロック」はアプリをブロックせず、時間表の編集だけを難しくします（④）。',
  'hub_important': 'アプリを選ぶだけでは動きません。時間帯がないと24時間ブロックにはならず、スケジュール自体が適用されません。',
  'master_on': 'スケジュールを使用',
  'master_off_sub': 'オフにすると時間帯と通知はすべて無効',
  'notif_title': '開始・終了の通知',
  'notif_on': '時間帯のオン/オフで通知（7日先まで予約）',
  'notif_need_master': 'スケジュールをオンにすると通知を予約できます',
  'notif_permission': '通知の許可が必要です。設定 → Isle → 通知で許可してください。',
  'schedule_list': 'スケジュール一覧',
  'volt_resume': 'アプリ終了中はiOSがタイマーを動かしません。再起動時にタイムスタンプで境界を同期します。',
  'lock_master_blocked': '設定ロック中の有効スケジュールがあります。④で解除カウントダウンを完了してください。',
  'window_sheet_title': 'スケジュール時間帯',
  'window_sheet_desc': '曜日と「開始 → 終了」を設定。複数追加できます。',
  'window_empty': 'まだ時間帯がありません',
  'window_add': '時間帯を追加',
  'window_edit': '時間帯を編集',
  'picker_title': '時間帯中の動作',
  'picker_sub': '時間帯内でアプリをどう制限するか。アプリロックは補助的なオプションです。',
  'scenario_heading': '実際の動き',
  'edit_flow': '① 時間帯 → ② アプリ制限（任意） → ③ 時間上限（任意） → ④ 設定ロック（任意）\n'
      '設定ロックはアプリブロックではありません。',
  'step1_title': 'いつ適用するか（時間表）',
  'step1_sub': '曜日・開始・長さを設定。曜日ごとに違う場合は複数追加。',
  'step2_title': '時間帯中の動作',
  'step2_sub': 'アプリロック / 時間のみ / 両方 — 時間表が先、アプリ制限は次',
  'step3_title': '時間上限（任意）',
  'step3_sub': 'ロックの代わりに「1時間N分」。Screen Time に別登録。',
  'step4_title': '設定ロック（任意）',
  'step4_sub': '時間表の編集だけを難しくします。アプリ制限とは別です。',
  'no_windows_yet': '時間帯がありません。追加しないとスケジュールは動きません。',
  'schedule_name': 'スケジュール名',
  'schedule_enabled': 'このスケジュールを使用',
  'save': '保存',
  'saving': '保存中…',
  'pick_apps_shield': 'アプリ制限 — Screen Timeで選択',
  'pick_apps_limit': '時間上限用アプリ（Screen Time）',
  'pick_apps_fallback': '空の場合は設定のグローバル選択を使います。',
  'shield_when_slot': '時間帯がオンになるとOSが選択アプリをロックします。',
  'limit_when_slot': '時間帯{when}で1時間あたりの上限が適用されます。',
  'active_now': '現在アクティブ — Screen Timeに反映中',
  'block_isle_in_app': 'Isle内も制限',
  'block_isle_sub': 'オンでWebView等も制限。オフなら時間帯中もIsleのYouTubeは視聴可。',
  'check_step1': '① スケジュール時間帯',
  'check_step1_need': '時間帯を1つ以上追加',
  'check_step1_ok': 'スロット {n} 件',
  'check_step2': '② アプリ制限（任意）',
  'check_step2_need': 'Screen Timeでロックするアプリを選択',
  'check_step2_ok': 'アプリ {apps} · カテゴリ {cats}',
  'check_step2_optional': '現在の方式ではアプリロックは必須ではありません',
  'check_footer': 'アプリ選択だけでは不十分です。①の時間帯が必要です。',
  'ready': '設定完了の準備OK',
  'not_ready': '完了前のチェック',
  'limit_hint_full': 'フルロックでは時間帯外の上限は不要です。方式を変えるとここで設定できます。',
  'mode_full_label': '時間帯中はアプリロック',
  'mode_full_sub': '時間帯がオンの間、選択アプリは開けません。最も強い制限です。',
  'mode_limit_label': '時間帯中もN分まで',
  'mode_limit_sub': 'アプリロックなし。1時間あたりN分（例: 8分）まで。',
  'mode_combo_label': '時間帯はロック＋普段はN分',
  'mode_combo_sub': '時間帯中はロック、その他は1時間N分。',
  'mode_full_scenario': '例) 9–12時 集中 →\n'
      '• Instagram等をScreen Timeでロック\n'
      '• IsleのYouTubeは「Isle内も制限」オン時のみ\n'
      '12時以降 → 制限なし',
  'mode_limit_scenario': '例) 9–12時 →\n'
      '• 1時間8分まで\n'
      '• アイコンロックなし\n'
      '12時以降 → 制限なし',
  'mode_combo_scenario': '例) 9–12時 → ロック\n'
      'それ以外 → 1時間N分',
  'overlay_title': 'スケジュール時間 — Screen Timeを確認',
  'overlay_body': 'いまはスケジュール時間帯です。\n'
      'アプリ制限はScreen Timeで確認してください。',
  'preset_name': '集中スケジュール',
  'schedule_empty_list': 'スケジュールがありません。下から追加してください。',
  'add_schedule': 'スケジュールを追加',
  'change_apps': 'アプリ制限を変更',
  'active_chip': ' · 現在アクティブ',
  'slots_count': 'スロット{n}件',
};

const _zh = <String, String>{
  'hub_title': '应用日程',
  'hub_intro': '① 计划时段 → ② 应用限制（可选） → ③ 时长上限（可选）。点按各日程进行设置。',
  'hub_lock_note': '「日程锁定」只防止改时间表，不会封锁应用（步骤 ④）。',
  'hub_important': '只选应用不够，必须有计划时段日程才会生效。没有时段不会 24 小时封锁，而是整个日程不生效。',
  'master_on': '启用日程',
  'master_off_sub': '关闭后时段与通知都不会应用',
  'notif_title': '开始与结束提醒',
  'notif_on': '时段开启或关闭时提醒（最多提前 7 天）',
  'notif_need_master': '需先开启日程才能预约提醒',
  'notif_permission': '需要通知权限。请在 设置 → Isle → 通知 中允许。',
  'schedule_list': '日程列表',
  'volt_resume': '应用关闭时 iOS 不会运行计时器。重新打开会按时间戳同步边界。',
  'lock_master_blocked': '有已启用的日程处于锁定状态。请先在步骤 ④ 完成解锁倒计时。',
  'window_sheet_title': '计划时段',
  'window_sheet_desc': '选择星期与「开始 → 结束」时间，可添加多个时段。',
  'window_empty': '还没有计划时段',
  'window_add': '添加计划时段',
  'window_edit': '编辑时段',
  'picker_title': '时段内的行为',
  'picker_sub': '在计划时段内如何限制应用。应用封锁为次要选项。',
  'scenario_heading': '实际效果',
  'edit_flow': '① 时段 → ② 应用限制（可选） → ③ 时长上限（可选） → ④ 日程锁定（可选）\n'
      '日程锁定不会封锁应用。',
  'step1_title': '何时生效（时间表）',
  'step1_sub': '设置星期、开始与时长。若每天不同可添加多个时段。',
  'step2_title': '时段内行为',
  'step2_sub': '应用锁定 / 仅限时 / 两者 — 时间表优先，应用规则其次',
  'step3_title': '时长上限（可选）',
  'step3_sub': '用「每小时 N 分钟」代替完全锁定，在屏幕使用时间中单独登记。',
  'step4_title': '日程锁定（可选）',
  'step4_sub': '仅让改时间表变难，与应用限制无关。',
  'no_windows_yet': '还没有时段。至少添加一个此日程才会生效。',
  'schedule_name': '日程名称',
  'schedule_enabled': '启用此日程',
  'save': '保存',
  'saving': '保存中…',
  'pick_apps_shield': '限制应用 — 屏幕使用时间选择',
  'pick_apps_limit': '用于时长上限的应用',
  'pick_apps_fallback': '若为空则使用设置中的全局应用选择。',
  'shield_when_slot': '时段开启时，系统会锁定所选应用。',
  'limit_when_slot': '在时段{when}应用每小时上限。',
  'active_now': '当前生效 — 正在同步到屏幕使用时间',
  'block_isle_in_app': '在 Isle 内也限制',
  'block_isle_sub': '开启会限制 Isle 内 WebView 等。关闭则时段内仍可在 Isle 看 YouTube。',
  'check_step1': '① 计划时段',
  'check_step1_need': '请至少添加一个时段',
  'check_step1_ok': '已设 {n} 个时段',
  'check_step2': '② 应用限制（可选）',
  'check_step2_need': '在屏幕使用时间中选择要锁定的应用',
  'check_step2_ok': '{apps} 个应用 · {cats} 个类别',
  'check_step2_optional': '当前模式不要求应用锁定',
  'check_footer': '只选应用不够，必须先完成 ① 计划时段。',
  'ready': '可以完成设置',
  'not_ready': '完成前检查',
  'limit_hint_full': '完全锁定模式不需要时段外上限。更改行为方式后可在此设置。',
  'mode_full_label': '时段内锁定应用',
  'mode_full_sub': '时段开启时无法打开所选应用，限制最强。',
  'mode_limit_label': '时段内仅允许 N 分钟',
  'mode_limit_sub': '不锁定图标，仅每小时 N 分钟（如 8 分钟）。',
  'mode_combo_label': '时段内锁定 + 平时 N 分钟',
  'mode_combo_sub': '时段内锁定，其余时间每小时 N 分钟。',
  'mode_full_scenario': '例）9–12 点专注 →\n'
      '• Instagram 等经屏幕使用时间锁定\n'
      '• Isle YouTube 需开启「在 Isle 内也限制」\n'
      '12 点后 → 无限制',
  'mode_limit_scenario': '例）9–12 点 →\n'
      '• 每小时 8 分钟\n'
      '• 无图标锁\n'
      '12 点后 → 无限制',
  'mode_combo_scenario': '例）9–12 点锁定\n'
      '其他时间 → 每小时 N 分钟',
  'overlay_title': '计划时段 — 请检查屏幕使用时间',
  'overlay_body': '当前处于计划时段。\n'
      '应用限制请在屏幕使用时间中查看。',
  'preset_name': '专注日程',
  'schedule_empty_list': '暂无日程。请在下方添加。',
  'add_schedule': '添加日程',
  'change_apps': '更改应用限制',
  'active_chip': ' · 当前生效',
  'slots_count': '{n} 个时段',
};

const _he = <String, String>{
  'hub_title': 'לוח זמני אפליקציות',
  'hub_intro': '① חלונות זמן → ② הגבלת אפליקציות (אופציונלי) → ③ מגבלות זמן (אופציונלי). '
      'הקש על לוח לעריכה.',
  'hub_lock_note': '״נעילת לוח״ מגינה על עריכת הזמנים — לא על חסימת אפליקציות (שלב ④).',
  'hub_important': 'בחירת אפליקציות בלבד לא מספיקה. נדרשים חלונות זמן. '
      'בלי חלונות אין חסימה 24/7 — הלוח פשוט לא יופעל.',
  'master_on': 'הפעלת לוחות זמנים',
  'master_off_sub': 'כבוי — חלונות והתראות לא יחולו',
  'notif_title': 'התראות התחלה וסיום',
  'notif_on': 'התראה כשחלון נדלק או נכבה (עד 7 ימים קדימה)',
  'notif_need_master': 'הפעל לוחות כדי לתזמן התראות',
  'notif_permission': 'נדרשת הרשאת התראות. אפשר ב: הגדרות → Isle → התראות.',
  'schedule_list': 'רשימת לוחות',
  'volt_resume': 'iOS לא מריץ טיימרים כשהאפליקציה סגורה. פתיחה מחדש מסנכרנת לפי חותמת זמן.',
  'lock_master_blocked': 'לוח פעיל עם נעילת הגדרות. סיים ספירה לאחור בשלב ④.',
  'window_sheet_title': 'חלונות זמן',
  'window_sheet_desc': 'בחר ימים ושעת התחלה → סיום. ניתן להוסיף כמה חלונות.',
  'window_empty': 'אין עדיין חלונות זמן',
  'window_add': 'הוסף חלון זמן',
  'window_edit': 'ערוך חלונות',
  'picker_title': 'במהלך חלון הזמן',
  'picker_sub': 'איך אפליקציות מתנהגות בחלון. נעילת אפליקציה היא משנית.',
  'scenario_heading': 'מה קורה בפועל?',
  'edit_flow': '① חלונות → ② הגבלת אפליקציות (אופציונלי) → ③ מגבלות (אופציונלי) → ④ נעילת לוח (אופציונלי)\n'
      'נעילת לוח לא חוסמת אפליקציות.',
  'step1_title': 'מתי זה פעיל (לוח זמנים)',
  'step1_sub': 'ימים, התחלה ומשך. הוסף חלונות אם הימים שונים.',
  'step2_title': 'התנהגות בחלון',
  'step2_sub': 'נעילה / זמן בלבד / שניהם — לוח קודם, אפליקציות אחר כך',
  'step3_title': 'מגבלות זמן (אופציונלי)',
  'step3_sub': '״N דקות לשעה״ במקום נעילה מלאה. נרשם בנפרד בזמן מסך.',
  'step4_title': 'נעילת לוח (אופציונלי)',
  'step4_sub': 'מקשה על שינוי לוח הזמנים. נפרד מהגבלת אפליקציות.',
  'no_windows_yet': 'אין חלונות. הוסף לפחות אחד כדי שהלוח יעבוד.',
  'schedule_name': 'שם לוח',
  'schedule_enabled': 'הפעל לוח זה',
  'save': 'שמירה',
  'saving': 'שומר…',
  'pick_apps_shield': 'הגבל אפליקציות — בוחר זמן מסך',
  'pick_apps_limit': 'אפליקציות למגבלת זמן',
  'pick_apps_fallback': 'אם ריק — משתמשים בבחירה הגלובלית בהגדרות.',
  'shield_when_slot': 'כשחלון פעיל, iOS נועל את האפליקציות שנבחרו.',
  'limit_when_slot': 'מגבלה לשעה חלה {when} החלון.',
  'active_now': 'פעיל עכשיו — מסתנכרן לזמן מסך',
  'block_isle_in_app': 'הגבל גם בתוך Isle',
  'block_isle_sub': 'חוסם WebView וכו׳. כבוי — YouTube ב-Isle עשוי להישאר זמין.',
  'check_step1': '① חלונות זמן',
  'check_step1_need': 'הוסף לפחות חלון אחד',
  'check_step1_ok': '{n} חלונות הוגדרו',
  'check_step2': '② הגבלת אפליקציות (אופציונלי)',
  'check_step2_need': 'בחר אפליקציות לנעילה בזמן מסך',
  'check_step2_ok': '{apps} אפליקציות · {cats} קטגוריות',
  'check_step2_optional': 'במצב הנוכחי נעילת אפליקציה לא חובה',
  'check_footer': 'בחירת אפליקציות לא מספיקה — נדרשים חלונות בשלב ①.',
  'ready': 'מוכן לסיום',
  'not_ready': 'לפני סיום',
  'limit_hint_full': 'במצב נעילה מלאה אין צורך במגבלה מחוץ לחלון. שנה התנהגות למעלה.',
  'mode_full_label': 'נעילת אפליקציות בחלון',
  'mode_full_sub': 'לא ניתן לפתוח אפליקציות שנבחרו כשהחלון פעיל. החזק ביותר.',
  'mode_limit_label': 'רק N דקות לשעה',
  'mode_limit_sub': 'בלי נעילת אייקון — תקרה לשעה (למשל 8 דק׳).',
  'mode_combo_label': 'נעילה בחלון + תקרה מחוץ',
  'mode_combo_sub': 'נעילה בחלון; מגבלה לשעה בשאר היום.',
  'mode_full_scenario': 'לדוגמה 9–12 →\n'
      '• Instagram ננעל בזמן מסך\n'
      '• YouTube ב-Isle רק עם ״גם בתוך Isle״\n'
      'אחרי 12 — ללא מגבלה',
  'mode_limit_scenario': 'לדוגמה 9–12 →\n'
      '• עד 8 דק׳ לשעה\n'
      '• בלי נעילת אייקון\n'
      'אחרי 12 — ללא מגבלה',
  'mode_combo_scenario': 'לדוגמה 9–12 → נעילה\n'
      'שאר היום → N דק׳ לשעה',
  'overlay_title': 'זמן מתוזמן — בדוק זמן מסך',
  'overlay_body': 'אתה בחלון זמן פעיל.\n'
      'הגבלות אפליקציה מנוהלות בזמן מסך.',
  'preset_name': 'לוח ריכוז',
  'schedule_empty_list': 'אין לוחות. הוסף למטה.',
  'add_schedule': 'הוסף לוח',
  'change_apps': 'שנה הגבלת אפליקציות',
  'active_chip': ' · פעיל עכשיו',
  'slots_count': '{n} חלונות',
};
