import 'package:flutter/material.dart';
import 'app_locale_policy.dart';

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
    return AppLocalePolicy.translate(_tables, lang, key, args: args);
  }

  String modeLabel(ScheduleEnforcementMode mode) => t(switch (mode) {
        ScheduleEnforcementMode.fullBlock => 'mode_full_label',
        ScheduleEnforcementMode.limitInSlot => 'mode_limit_label',
        ScheduleEnforcementMode.blockInSlotLimitOutside => 'mode_combo_label',
      });

  String modeScenario(ScheduleEnforcementMode mode) => t(switch (mode) {
        ScheduleEnforcementMode.fullBlock => 'mode_full_scenario',
        ScheduleEnforcementMode.limitInSlot => 'mode_limit_scenario',
        ScheduleEnforcementMode.blockInSlotLimitOutside =>
          'mode_combo_scenario',
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
  'wake_targets_title': '기상 후 2시간 잠금 대상',
  'wake_targets_subtitle': '차단할 화면을 직접 골라요',
  'wake_targets_hint':
      '켜진 항목만 기상 후 잠겨요. QR 스캐너는 항상 허용되고, Safari를 허용하려면 브라우저를 꺼 두세요.',
  'wake_target_instagram': 'Instagram 피드·탐색',
  'wake_target_dm': 'Instagram 메시지',
  'wake_target_youtube': 'YouTube',
  'wake_target_brunch': 'Brunch',
  'wake_target_browser': 'MOA 내부 Safari·웹 브라우저',
  'wake_qr_allowed': 'QR 스캐너 · 항상 허용',
  'wake_external_apps_empty': 'iPhone 앱 선택 없음',
  'wake_external_apps_summary': 'iPhone 앱 {apps}개 · 카테고리 {categories}개 선택됨',
  'wake_external_apps_hint':
      '개별 iPhone 앱 또는 선택한 카테고리만 추가로 잠겨요. Safari를 허용하려면 Safari 앱과 포함될 수 있는 카테고리를 선택하지 마세요. QR 스캐너는 MOA 안에서 계속 사용할 수 있어요.',
  'wake_external_apps_button': 'iPhone에서 잠글 앱 선택',
  'wake_apps_pick_cancelled': '앱 선택이 취소됐거나 Screen Time 권한이 없어요.',
  'wake_apps_additive_only': '기상 잠금 중에는 기존 선택을 풀지 못하고 앱을 추가만 할 수 있어요.',
  'hub_help_body': '스케줄을 눌러 ①언제 ②어떻게 ③무엇을 막을지 정하세요. '
      '앱만 고르고 시간대가 없으면 동작하지 않아요 — ①이 꼭 필요해요.\n'
      '④ 설정 잠금은 시간표 수정만 어렵게 할 뿐, 앱 차단과는 별개예요.\n'
      '앱이 꺼져 있으면 iOS가 타이머를 안 돌려서, 다시 열 때 시간을 다시 맞춰요.',
  'hub_status_idle': '{n}개 스케줄 · 지금은 대기 중',
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
  'schedule_settings': '스케줄 설정',
  'lock_master_blocked': '설정 잠금이 켜진 활성 스케줄이 있어요. '
      '스케줄 편집 ④에서 잠금 해제 카운트다운을 먼저 완료하세요.',
  'window_sheet_title': '일정 시간대',
  'window_sheet_desc': '적용할 요일과 「시작 → 종료」 시각을 정하세요. 시간대는 여러 개 추가할 수 있어요.',
  'window_empty': '아직 일정 시간대가 없어요',
  'window_add': '일정 시간대 추가',
  'window_edit': '시간대 편집',
  'picker_title': '제한 방식',
  'picker_sub': '일정이 켜진 동안의 동작',
  'edit_flow': '① 언제 → ② 방식 → ③ 대상 → ④ 설정 잠금(선택)',
  'step1_title': '언제',
  'step1_sub': '요일·시간. 다르면 시간대를 추가하세요.',
  'step2_title': '방식',
  'step2_sub': '',
  'step3_title': '막을 대상',
  'step3_sub': '완전 차단 = 체크박스 · 시간 한도 = 아래 접어서(선택)',
  'step4_title': '설정 잠금',
  'step4_sub': '시간표 수정만 어렵게 (앱 차단 아님)',
  'active_blocking': '지금 이 스케줄 적용 중',
  'active_blocking_locked': '적용 중 · 설정 잠금 — 해제 후 5분만 편집',
  'no_windows_yet': '아직 일정 시간대가 없어요. 시간대를 추가해야 이 스케줄이 동작합니다.',
  'schedule_name': '스케줄 이름',
  'schedule_name_hint': '메모용 이름이에요. 실제 차단은 ③ 막을 대상에서 고릅니다.',
  'target_explainer_body': '체크한 것만 막아요. 이름(safari)은 메모일 뿐이에요.\n'
      '· Isle 유튜브 = 앱 안 /youtube\n'
      '· iPhone 앱 = Screen Time 잠금\n'
      '· ④ 웹 도메인 = Safari 등 브라우저 (Isle 시청과 별개)',
  'target_domain_youtube_only': '④에 youtube 도메인만 있어요 — Isle 유튜브 체크는 꺼져 있어요.',
  'target_name_mismatch':
      '이름은 Safari인데 Isle 유튜브가 켜져 있어요. 이름을 바꾸거나 ③에서 대상을 확인하세요.',
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
  'limit_hint_full': '앱 잠금 모드에서는 슬롯 밖 한도가 필요 없어요. 방식을 바꾸면 여기서 설정할 수 있어요.',
  'mode_full_label': '일정 중 앱 잠금',
  'mode_limit_label': '일정 중 N분만',
  'mode_combo_label': '일정 잠금 + 평소 N분',
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
  'wake_targets_title': 'Apps blocked for 2 hours after waking',
  'wake_targets_subtitle': 'Choose which screens to block',
  'wake_targets_hint':
      'Only enabled items are blocked. QR scanning is always allowed. Turn off the browser to allow Safari.',
  'wake_target_instagram': 'Instagram feed and Explore',
  'wake_target_dm': 'Instagram messages',
  'wake_target_youtube': 'YouTube',
  'wake_target_brunch': 'Brunch',
  'wake_target_browser': 'MOA in-app Safari and web browser',
  'wake_qr_allowed': 'QR scanner · always allowed',
  'wake_external_apps_empty': 'No iPhone apps selected',
  'wake_external_apps_summary':
      '{apps} iPhone apps · {categories} categories selected',
  'wake_external_apps_hint':
      'Selected iPhone apps or categories are additionally blocked. Leave Safari and any category that includes it unselected to allow it. QR scanning inside MOA stays available.',
  'wake_external_apps_button': 'Choose iPhone apps to block',
  'wake_apps_pick_cancelled':
      'App selection was cancelled or Screen Time permission is missing.',
  'wake_apps_additive_only':
      'While the wake lock is active, you can add apps but cannot remove the existing selection.',
  'hub_help_body': 'Tap a schedule: ① when ② how ③ what to limit. '
      'Picking apps alone is not enough — without windows in step ①, nothing runs.\n'
      '④ Schedule lock only protects your timetable from edits, separate from app blocking.\n'
      'iOS won’t run timers while the app is closed — reopening syncs boundaries from timestamps.',
  'hub_status_idle': '{n} schedules · idle right now',
  'edit_help_body': '① When — days & times\n'
      '② How — lock / minutes / both\n'
      '③ Targets — Isle & iPhone apps\n'
      '④ Schedule lock — optional (not app blocking)',
  'active_blocking': 'This schedule is active now',
  'active_blocking_locked':
      'Active · schedule lock — edit for 5 min after unlock',
  'schedule_settings': 'Schedule settings',
  'master_on': 'Use schedules',
  'master_off_sub': 'When off, windows and alerts won’t apply',
  'notif_title': 'Schedule start & end alerts',
  'notif_on': 'Notify when a window turns on or off (booked 7 days ahead)',
  'notif_need_master': 'Turn schedules on to book alerts',
  'notif_permission':
      'Notifications are required. Allow them in Settings → Isle → Notifications.',
  'schedule_list': 'Your schedules',
  'lock_master_blocked':
      'An active schedule has schedule lock on. Finish the unlock countdown in step ④ first.',
  'window_sheet_title': 'Schedule windows',
  'window_sheet_desc':
      'Choose days and a start → end time. You can add multiple windows.',
  'window_empty': 'No schedule windows yet',
  'window_add': 'Add schedule window',
  'window_edit': 'Edit windows',
  'picker_title': 'During scheduled times',
  'picker_sub':
      'How apps behave in your windows. App lock is optional and secondary.',
  'edit_flow':
      '① Windows → ② Restrict apps (optional) → ③ Time limits (optional) → ④ Schedule lock (optional)\n'
          'Schedule lock does not block apps.',
  'step1_title': 'When it runs (timetable)',
  'step1_sub':
      'Set days, start, and duration. Add multiple windows if days differ.',
  'step2_title': 'Behavior in windows',
  'step2_sub':
      'App lock / time only / both — timetable first, app rules second',
  'step3_title': 'Time limits (optional)',
  'step3_sub':
      'Use “N minutes per hour” instead of a full lock. Registered separately in Screen Time.',
  'step4_title': 'Schedule lock (optional)',
  'step4_sub': 'Makes timetable edits harder. Separate from restricting apps.',
  'no_windows_yet':
      'No windows yet. Add at least one for this schedule to work.',
  'schedule_name': 'Schedule name',
  'schedule_name_hint':
      'Just a label for you. Actual blocking is set in ③ Targets.',
  'target_explainer_body':
      'Only checked items are blocked. The name (e.g. safari) is just a label.\n'
          '· Isle YouTube = in-app /youtube\n'
          '· iPhone apps = Screen Time lock\n'
          '· ④ Web domains = Safari & other browsers (separate from Isle viewing)',
  'target_domain_youtube_only':
      'Step ④ has only youtube domains — the Isle YouTube checkbox is off.',
  'target_name_mismatch':
      'The name says Safari but Isle YouTube is on. Rename it or check targets in ③.',
  'schedule_enabled': 'Enable this schedule',
  'save': 'Save',
  'saving': 'Saving…',
  'pick_apps_shield': 'Restrict apps — Screen Time picker',
  'pick_apps_limit': 'Apps for time limits (Screen Time)',
  'pick_apps_fallback':
      'If empty, the global app selection in Settings is used.',
  'shield_when_slot': 'While a window is active, iOS locks the chosen apps.',
  'limit_when_slot': 'Per-hour limits apply {when} the window.',
  'active_now': 'Active now — syncing to Screen Time.',
  'block_isle_in_app': 'Also limit inside Isle',
  'block_isle_sub':
      'Blocks Isle WebView and in-app browsers. When off, YouTube in Isle may still work during windows.',
  'check_step1': '① Schedule windows',
  'check_step1_need': 'Add at least one window',
  'check_step1_ok': '{n} window(s) set',
  'check_step2': '② Restrict apps (optional)',
  'check_step2_need': 'Pick apps to lock in Screen Time',
  'check_step2_ok': '{apps} apps · {cats} categories',
  'check_step2_optional': 'Current mode doesn’t require app lock',
  'check_footer':
      'App picks alone aren’t enough—windows in step ① are required.',
  'ready': 'Ready to finish',
  'limit_hint_full':
      'Full lock mode doesn’t need outside-window limits. Change behavior above to adjust.',
  'mode_full_label': 'Lock apps during window',
  'mode_limit_label': 'Allow N minutes per hour',
  'mode_combo_label': 'Lock in window + cap outside',
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
  'wake_targets_title': '起床後2時間のロック対象',
  'wake_targets_subtitle': 'ロックする画面を選択',
  'wake_targets_hint':
      'オンにした項目だけロックします。QRスキャンは常に利用でき、Safariを許可するにはブラウザーをオフにします。',
  'wake_target_instagram': 'Instagramフィード・検索',
  'wake_target_dm': 'Instagramメッセージ',
  'wake_target_youtube': 'YouTube',
  'wake_target_brunch': 'Brunch',
  'wake_target_browser': 'MOA内Safari・ウェブブラウザー',
  'wake_qr_allowed': 'QRスキャナー · 常に許可',
  'wake_external_apps_empty': 'iPhoneアプリ未選択',
  'wake_external_apps_summary': 'iPhoneアプリ{apps}個 · カテゴリ{categories}個',
  'wake_external_apps_hint':
      '選択したiPhoneアプリやカテゴリだけ追加でロックします。Safariを許可するにはSafariと該当カテゴリを選択しないでください。MOA内QRスキャンは引き続き使えます。',
  'wake_external_apps_button': 'ロックするiPhoneアプリを選択',
  'wake_apps_pick_cancelled': '選択がキャンセルされたか、Screen Time権限がありません。',
  'wake_apps_additive_only': '起床ロック中は既存の選択を解除できず、追加のみ可能です。',
  'hub_help_body': '① スケジュール時間帯 → ② アプリ制限（任意） → ③ 時間上限（任意）。各項目をタップして設定。'
      'アプリを選ぶだけでは動きません。①の時間帯が必要です。\n'
      '「設定ロック」はアプリをブロックせず、時間表の編集だけを難しくします（④）。\n'
      'アプリ終了中はiOSがタイマーを動かしません。再起動時にタイムスタンプで境界を同期します。',
  'hub_status_idle': '{n}件のスケジュール · 現在は待機中',
  'edit_help_body': '① いつ — 曜日・時間\n'
      '② 方式 — ロック / N分だけ / 両方\n'
      '③ 対象 — Isle・iPhoneアプリのチェック\n'
      '④ 設定ロック — 任意（アプリブロックとは別）',
  'schedule_settings': 'スケジュール設定',
  'master_on': 'スケジュールを使用',
  'master_off_sub': 'オフにすると時間帯と通知はすべて無効',
  'notif_title': '開始・終了の通知',
  'notif_on': '時間帯のオン/オフで通知（7日先まで予約）',
  'notif_need_master': 'スケジュールをオンにすると通知を予約できます',
  'notif_permission': '通知の許可が必要です。設定 → Isle → 通知で許可してください。',
  'schedule_list': 'スケジュール一覧',
  'lock_master_blocked': '設定ロック中の有効スケジュールがあります。④で解除カウントダウンを完了してください。',
  'window_sheet_title': 'スケジュール時間帯',
  'window_sheet_desc': '曜日と「開始 → 終了」を設定。複数追加できます。',
  'window_empty': 'まだ時間帯がありません',
  'window_add': '時間帯を追加',
  'window_edit': '時間帯を編集',
  'picker_title': '時間帯中の動作',
  'picker_sub': '時間帯内でアプリをどう制限するか。アプリロックは補助的なオプションです。',
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
  'schedule_name_hint': 'メモ用の名前です。実際のブロックは③で選びます。',
  'target_explainer_body': 'チェックした項目だけをブロックします。名前(例: safari)はメモにすぎません。\n'
      '· Isle YouTube = アプリ内 /youtube\n'
      '· iPhoneアプリ = Screen Time ロック\n'
      '· ④ Webドメイン = Safari等のブラウザ（Isle視聴とは別）',
  'target_domain_youtube_only':
      '④にyoutubeドメインだけがあります — Isle YouTubeのチェックはオフです。',
  'target_name_mismatch': '名前はSafariですがIsle YouTubeがオンです。名前を変えるか③で対象を確認してください。',
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
  'limit_hint_full': 'フルロックでは時間帯外の上限は不要です。方式を変えるとここで設定できます。',
  'mode_full_label': '時間帯中はアプリロック',
  'mode_limit_label': '時間帯中もN分まで',
  'mode_combo_label': '時間帯はロック＋普段はN分',
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
  'wake_targets_title': '起床后两小时的锁定目标',
  'wake_targets_subtitle': '选择要锁定的页面',
  'wake_targets_hint': '仅锁定已开启的项目。二维码扫描始终可用；如要允许 Safari，请关闭浏览器选项。',
  'wake_target_instagram': 'Instagram 信息流与探索',
  'wake_target_dm': 'Instagram 私信',
  'wake_target_youtube': 'YouTube',
  'wake_target_brunch': 'Brunch',
  'wake_target_browser': 'MOA 内 Safari 与网页浏览器',
  'wake_qr_allowed': '二维码扫描 · 始终允许',
  'wake_external_apps_empty': '未选择 iPhone 应用',
  'wake_external_apps_summary': '已选 {apps} 个 iPhone 应用 · {categories} 个类别',
  'wake_external_apps_hint':
      '只会额外锁定已选的 iPhone 应用或类别。如要允许 Safari，请勿选择 Safari 或包含它的类别；MOA 内的二维码扫描仍可使用。',
  'wake_external_apps_button': '选择要锁定的 iPhone 应用',
  'wake_apps_pick_cancelled': '应用选择已取消，或缺少 Screen Time 权限。',
  'wake_apps_additive_only': '起床锁定期间只能添加应用，不能移除已有选择。',
  'hub_help_body': '① 计划时段 → ② 应用限制（可选） → ③ 时长上限（可选）。点按各日程进行设置。'
      '只选应用不够，必须有 ① 计划时段才会生效。\n'
      '「日程锁定」只防止改时间表，不会封锁应用（步骤 ④）。\n'
      '应用关闭时 iOS 不会运行计时器，重新打开会按时间戳同步边界。',
  'hub_status_idle': '{n} 个日程 · 当前待机中',
  'edit_help_body': '① 何时 — 星期·时间\n'
      '② 方式 — 锁定 / 仅N分钟 / 两者都\n'
      '③ 对象 — Isle·iPhone 应用勾选\n'
      '④ 日程锁定 — 可选（与应用封锁无关）',
  'schedule_settings': '日程设置',
  'master_on': '启用日程',
  'master_off_sub': '关闭后时段与通知都不会应用',
  'notif_title': '开始与结束提醒',
  'notif_on': '时段开启或关闭时提醒（最多提前 7 天）',
  'notif_need_master': '需先开启日程才能预约提醒',
  'notif_permission': '需要通知权限。请在 设置 → Isle → 通知 中允许。',
  'schedule_list': '日程列表',
  'lock_master_blocked': '有已启用的日程处于锁定状态。请先在步骤 ④ 完成解锁倒计时。',
  'window_sheet_title': '计划时段',
  'window_sheet_desc': '选择星期与「开始 → 结束」时间，可添加多个时段。',
  'window_empty': '还没有计划时段',
  'window_add': '添加计划时段',
  'window_edit': '编辑时段',
  'picker_title': '时段内的行为',
  'picker_sub': '在计划时段内如何限制应用。应用封锁为次要选项。',
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
  'schedule_name_hint': '这只是备注名称。实际封锁在 ③ 目标中设置。',
  'target_explainer_body': '仅封锁勾选的项目。名称(如 safari)只是备注。\n'
      '· Isle YouTube = 应用内 /youtube\n'
      '· iPhone 应用 = 屏幕使用时间锁定\n'
      '· ④ 网站域名 = Safari 等浏览器（与 Isle 观看无关）',
  'target_domain_youtube_only': '步骤 ④ 只有 youtube 域名 — Isle YouTube 复选框未开启。',
  'target_name_mismatch': '名称是 Safari，但 Isle YouTube 已开启。请重命名或在 ③ 中检查目标。',
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
  'limit_hint_full': '完全锁定模式不需要时段外上限。更改行为方式后可在此设置。',
  'mode_full_label': '时段内锁定应用',
  'mode_limit_label': '时段内仅允许 N 分钟',
  'mode_combo_label': '时段内锁定 + 平时 N 分钟',
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
  'wake_targets_title': 'אפליקציות לנעילה לשעתיים אחרי היקיצה',
  'wake_targets_subtitle': 'בחירת המסכים לנעילה',
  'wake_targets_hint':
      'רק פריטים מופעלים יינעלו. סריקת QR תמיד מותרת; כדי לאפשר Safari, כבו את הדפדפן.',
  'wake_target_instagram': 'הפיד והחיפוש של Instagram',
  'wake_target_dm': 'הודעות Instagram',
  'wake_target_youtube': 'YouTube',
  'wake_target_brunch': 'Brunch',
  'wake_target_browser': 'Safari ודפדפן בתוך MOA',
  'wake_qr_allowed': 'סורק QR · תמיד מותר',
  'wake_external_apps_empty': 'לא נבחרו אפליקציות iPhone',
  'wake_external_apps_summary':
      'נבחרו {apps} אפליקציות iPhone · {categories} קטגוריות',
  'wake_external_apps_hint':
      'רק אפליקציות iPhone או קטגוריות שנבחרו יינעלו בנוסף. כדי לאפשר Safari, אל תבחרו בו או בקטגוריה שעשויה לכלול אותו. סריקת QR בתוך MOA תישאר זמינה.',
  'wake_external_apps_button': 'בחירת אפליקציות iPhone לנעילה',
  'wake_apps_pick_cancelled':
      'בחירת האפליקציות בוטלה או שאין הרשאת Screen Time.',
  'wake_apps_additive_only':
      'בזמן נעילת היקיצה ניתן להוסיף אפליקציות אך לא להסיר בחירות קיימות.',
  'hub_help_body':
      '① חלונות זמן → ② הגבלת אפליקציות (אופציונלי) → ③ מגבלות זמן (אופציונלי). '
          'הקש על לוח לעריכה. בחירת אפליקציות בלבד לא מספיקה — נדרשים חלונות זמן בשלב ①.\n'
          '״נעילת לוח״ מגינה על עריכת הזמנים בלבד — לא על חסימת אפליקציות (שלב ④).\n'
          'iOS לא מריץ טיימרים כשהאפליקציה סגורה. פתיחה מחדש מסנכרנת לפי חותמת זמן.',
  'hub_status_idle': '{n} לוחות · במצב המתנה כרגע',
  'edit_help_body': '① מתי — ימים ושעות\n'
      '② איך — נעילה / N דקות בלבד / שניהם\n'
      '③ יעדים — סימון אפליקציות Isle ו-iPhone\n'
      '④ נעילת לוח — אופציונלי (נפרד מחסימת אפליקציות)',
  'schedule_settings': 'הגדרות לוח זמנים',
  'master_on': 'הפעלת לוחות זמנים',
  'master_off_sub': 'כבוי — חלונות והתראות לא יחולו',
  'notif_title': 'התראות התחלה וסיום',
  'notif_on': 'התראה כשחלון נדלק או נכבה (עד 7 ימים קדימה)',
  'notif_need_master': 'הפעל לוחות כדי לתזמן התראות',
  'notif_permission': 'נדרשת הרשאת התראות. אפשר ב: הגדרות → Isle → התראות.',
  'schedule_list': 'רשימת לוחות',
  'lock_master_blocked': 'לוח פעיל עם נעילת הגדרות. סיים ספירה לאחור בשלב ④.',
  'window_sheet_title': 'חלונות זמן',
  'window_sheet_desc': 'בחר ימים ושעת התחלה → סיום. ניתן להוסיף כמה חלונות.',
  'window_empty': 'אין עדיין חלונות זמן',
  'window_add': 'הוסף חלון זמן',
  'window_edit': 'ערוך חלונות',
  'picker_title': 'במהלך חלון הזמן',
  'picker_sub': 'איך אפליקציות מתנהגות בחלון. נעילת אפליקציה היא משנית.',
  'edit_flow':
      '① חלונות → ② הגבלת אפליקציות (אופציונלי) → ③ מגבלות (אופציונלי) → ④ נעילת לוח (אופציונלי)\n'
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
  'schedule_name_hint': 'שם לתזכורת בלבד. החסימה בפועל נקבעת ב-③ יעדים.',
  'target_explainer_body':
      'רק פריטים מסומנים נחסמים. השם (למשל safari) הוא רק תווית.\n'
          '· Isle YouTube = בתוך האפליקציה /youtube\n'
          '· אפליקציות iPhone = נעילת זמן מסך\n'
          '· ④ דומייני אינטרנט = Safari ודפדפנים אחרים (נפרד מצפייה ב-Isle)',
  'target_domain_youtube_only':
      'בשלב ④ יש רק דומייני youtube — תיבת Isle YouTube כבויה.',
  'target_name_mismatch':
      'השם הוא Safari אבל Isle YouTube דלוק. שנה את השם או בדוק יעדים ב-③.',
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
  'block_isle_sub':
      'חוסם WebView וכו׳. כבוי — YouTube ב-Isle עשוי להישאר זמין.',
  'check_step1': '① חלונות זמן',
  'check_step1_need': 'הוסף לפחות חלון אחד',
  'check_step1_ok': '{n} חלונות הוגדרו',
  'check_step2': '② הגבלת אפליקציות (אופציונלי)',
  'check_step2_need': 'בחר אפליקציות לנעילה בזמן מסך',
  'check_step2_ok': '{apps} אפליקציות · {cats} קטגוריות',
  'check_step2_optional': 'במצב הנוכחי נעילת אפליקציה לא חובה',
  'check_footer': 'בחירת אפליקציות לא מספיקה — נדרשים חלונות בשלב ①.',
  'ready': 'מוכן לסיום',
  'limit_hint_full':
      'במצב נעילה מלאה אין צורך במגבלה מחוץ לחלון. שנה התנהגות למעלה.',
  'mode_full_label': 'נעילת אפליקציות בחלון',
  'mode_limit_label': 'רק N דקות לשעה',
  'mode_combo_label': 'נעילה בחלון + תקרה מחוץ',
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
