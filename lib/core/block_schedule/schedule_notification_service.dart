import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../navigation/isle_navigator_key.dart';
import '../navigation/isle_routes.dart';
import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'models/schedule_slot.dart';
import 'quick_block_service.dart';
import 'schedule_display_helper.dart';

/// 스케줄 슬롯 시작·종료 로컬 알림 (7일·최대 48건, resume 시 재등록)
class ScheduleNotificationService {
  ScheduleNotificationService._();

  static const _channelId = 'isle_schedule_block';
  static const _channelName = '차단 스케줄';
  static const _baseId = 41000;
  static const _targetEditBaseId = 41500;
  static const _maxPending = 48;
  static const _targetEditPayloadPrefix = 'schedule_edit:';
  static const _morningDigestBaseId = 41700;
  static const _morningDigestDays = 7;
  static const _morningDigestPayload = 'morning_digest';
  static const _scheduleNotifPayload = 'schedule_notif';

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      IsleAppLogService.log('schedule notif TZ fallback: $e', level: IsleLogLevel.warn);
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: '스케줄 차단 시작·종료 알림',
          importance: Importance.high,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _pomodoroChannelId,
          _pomodoroChannelName,
          description: '포모도로 휴식·집중 알림',
          importance: Importance.high,
        ),
      );
    }
    _initialized = true;
  }

  static const _pomodoroChannelId = 'isle_pomodoro';
  static const _pomodoroChannelName = '포모도로';
  static const _pomodoroBreakStartId = 42501;
  static const _pomodoroBreakEndId = 42502;

  /// 30분 집중 완료 → 휴식 시작 알림 + 휴식 종료 예약
  static Future<void> notifyPomodoroBreakStarted({
    required DateTime breakEndsAt,
    int breakMinutes = 10,
  }) async {
    await ensureInitialized();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _pomodoroChannelId,
        _pomodoroChannelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(
        _pomodoroBreakStartId,
        '🍵 휴식 시간',
        '$breakMinutes분 동안 잠깐 손 떼기 — 쇼츠·릴 쉬어가요',
        details,
      );
      final tzWhen = tz.TZDateTime.from(breakEndsAt, tz.local);
      if (tzWhen.isAfter(tz.TZDateTime.now(tz.local))) {
        await _plugin.zonedSchedule(
          _pomodoroBreakEndId,
          '🍅 집중 다시 시작',
          '휴식이 끝났어요. 30분 집중을 이어갈 수 있어요',
          tzWhen,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
      IsleAppLogService.log('Pomodoro break notification scheduled until $breakEndsAt');
    } catch (e, st) {
      IsleAppLogService.log('Pomodoro notif failed: $e', level: IsleLogLevel.warn, stack: st);
    }
  }

  static Future<void> cancelPomodoroNotifications() async {
    if (!_initialized) return;
    await _plugin.cancel(_pomodoroBreakStartId);
    await _plugin.cancel(_pomodoroBreakEndId);
  }

  /// OS에 알림 권한이 있는지 (팝업 없이 조회)
  static Future<bool> hasNotificationPermission() async {
    await ensureInitialized();
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final opts = await ios?.checkPermissions();
      return opts?.isEnabled == true;
    }
    if (Platform.isMacOS) {
      final mac = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      final opts = await mac?.checkPermissions();
      return opts?.isEnabled == true;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? true;
    }
    return true;
  }

  /// 알림 권한 요청 — 거부 시 false
  static Future<bool> requestPermission() async {
    await ensureInitialized();
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final ok = await ios?.requestPermissions(
        alert: true,
        badge: false,
        sound: true,
      );
      return ok ?? false;
    }
    if (Platform.isMacOS) {
      final mac = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      final ok = await mac?.requestPermissions(
        alert: true,
        badge: false,
        sound: true,
      );
      return ok ?? false;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ok = await android?.requestNotificationsPermission();
      return ok ?? false;
    }
    return false;
  }

  static Future<void> cancelAll() async {
    if (!_initialized) return;
    for (var i = 0; i < _maxPending; i++) {
      await _plugin.cancel(_baseId + i);
    }
    for (var i = 0; i < _morningDigestDays; i++) {
      await _plugin.cancel(_morningDigestBaseId + i);
    }
  }

  static int _targetEditNotifId(String scheduleId) =>
      _targetEditBaseId + (scheduleId.hashCode.abs() % 80);

  static const _unlockReadyBaseId = 41600;

  static int _unlockReadyNotifId(String scheduleId) =>
      _unlockReadyBaseId + (scheduleId.hashCode.abs() % 80);

  /// 차단 AI 챗에서 시작한 설정 잠금(타임락) 해제 카운트다운이 끝났을 때 —
  /// 앱을 다시 열어야만 알아채던 걸, 소리와 함께 바로 알려준다(2026-07-11 cage 요청:
  /// "타이머가 흐르겠지? 끝나면 알림과 알림음").
  static Future<void> scheduleUnlockCountdownReminder({
    required BlockSchedule schedule,
    required DateTime readyAt,
  }) async {
    // 이 함수는 챗·스와이프 해제 실행 경로에서 fire-and-forget으로 호출된다
    // (알림이 실패해도 실제 잠금 해제 자체는 막지 않아야 함) — 초기화·권한
    // 조회 단계에서 플러그인이 없는 테스트 환경 등에서 던지면 그 예외가
    // await 없이 전파돼 호출부를 깨뜨리므로, 이 함수 전체를 감싼다.
    try {
      await ensureInitialized();
      if (!await hasNotificationPermission()) return;

      final tzWhen = tz.TZDateTime.from(readyAt, tz.local);
      if (!tzWhen.isAfter(tz.TZDateTime.now(tz.local))) return;

      final id = _unlockReadyNotifId(schedule.id);
      await _plugin.zonedSchedule(
        id,
        '설정 잠금 해제됨',
        '「${schedule.name}」이제 편집·해제할 수 있어요',
        tzWhen,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
          macOS: const DarwinNotificationDetails(presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      IsleAppLogService.log('schedule unlock ready notif $id at $readyAt');
    } catch (e, st) {
      IsleAppLogService.log(
        'schedule unlock ready notif failed: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
    }
  }

  static Future<void> cancelUnlockCountdownReminder(String scheduleId) async {
    if (!_initialized) return;
    await _plugin.cancel(_unlockReadyNotifId(scheduleId));
  }

  /// 잠금 해제 후 앱 타깃 변경 적용 알림
  static Future<void> scheduleTargetEditReminder({
    required BlockSchedule schedule,
    required DateTime applyAt,
    required int pendingCount,
  }) async {
    await ensureInitialized();
    if (!await hasNotificationPermission()) return;

    final tzWhen = tz.TZDateTime.from(applyAt, tz.local);
    if (!tzWhen.isAfter(tz.TZDateTime.now(tz.local))) return;

    final id = _targetEditNotifId(schedule.id);
    final payload = '$_targetEditPayloadPrefix${schedule.id}';
    try {
      await _plugin.zonedSchedule(
        id,
        '스케줄 편집 가능',
        '「${schedule.name}」앱 변경 $pendingCount건 — 탭해서 적용하세요',
        tzWhen,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
          macOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      IsleAppLogService.log('schedule target edit notif $id at $applyAt');
    } catch (e, st) {
      IsleAppLogService.log(
        'schedule target edit notif failed: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
    }
  }

  static Future<void> cancelTargetEditReminder(String scheduleId) async {
    if (!_initialized) return;
    await _plugin.cancel(_targetEditNotifId(scheduleId));
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTap(NotificationResponse response) {
    _handleNotificationPayload(response.payload);
  }

  static void _onNotificationTap(NotificationResponse response) {
    _handleNotificationPayload(response.payload);
  }

  static void _handleNotificationPayload(String? payload) {
    if (payload == null) return;
    final ctx = isleNavigatorKey.currentContext;
    if (ctx == null) return;

    if (payload.startsWith(_targetEditPayloadPrefix)) {
      final scheduleId = payload.substring(_targetEditPayloadPrefix.length).trim();
      if (scheduleId.isEmpty) return;
      ctx.push(IsleRoutes.blockScheduleEditOutsideShell(scheduleId));
      return;
    }

    // "아침 알림"·"차단 시작/해제" 알림을 탭하면 알림 설정(아침 알림·전체 알림
    // 끄기 토글이 있는 화면)으로 바로 이동한다(2026-07-11 cage 요청:
    // "알림 클릭해서 아침 알림 끄기, 전체 알림 끄기 등을 설정할 수 있게").
    if (payload == _morningDigestPayload || payload == _scheduleNotifPayload) {
      ctx.push(IsleRoutes.blockSchedulesOutsideShell);
    }
  }

  /// 마스터·알림 설정·스케줄 변경 후 호출
  static Future<void> rescheduleAll() async {
    if (!IsleUserDefaults.scheduleBlockNotificationsEnabled ||
        !BlockScheduleStore.masterEnabled) {
      await cancelAll();
      return;
    }

    await ensureInitialized();
    if (!await hasNotificationPermission()) {
      IsleAppLogService.log(
        'schedule notif: skipped — permission off (설정에서 켜거나 알림 토글 시 요청)',
        level: IsleLogLevel.debug,
      );
      await cancelAll();
      return;
    }

    await cancelAll();

    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 7));
    final events = _collectTransitions(from: now, until: horizon);
    events.sort((a, b) => a.at.compareTo(b.at));

    var id = 0;
    for (final e in events.take(_maxPending)) {
      final tzWhen = tz.TZDateTime.from(e.at, tz.local);
      if (!tzWhen.isAfter(tz.TZDateTime.from(now, tz.local))) continue;
      try {
        // 알림 본문이 대상 요약·남은 시간까지 붙어 여러 줄일 수 있어(2026-07-11),
        // Android 기본 1줄 미리보기 대신 펼쳤을 때 전체가 보이게 BigTextStyle 사용.
        await _plugin.zonedSchedule(
          _baseId + id,
          e.starting ? '차단 시작' : '차단 해제',
          e.body,
          tzWhen,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(e.body),
            ),
            iOS: const DarwinNotificationDetails(),
            macOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: _scheduleNotifPayload,
        );
        id++;
      } catch (e, st) {
        IsleAppLogService.log('schedule notif schedule failed: $e', level: IsleLogLevel.warn, stack: st);
      }
    }
    IsleAppLogService.log('schedule notif: scheduled $id events');

    await _scheduleMorningDigests();
  }

  /// 매일 정해진 시각에 "오늘 뭐가 막히는지" 요약 알림 — 나머지 알림과 같은
  /// 방식(7일치 미리 예약, resume 때마다 갱신)으로 그날그날 실제 스케줄
  /// 내용을 반영한다(2026-07-11 cage 요청).
  static Future<void> _scheduleMorningDigests() async {
    for (var i = 0; i < _morningDigestDays; i++) {
      await _plugin.cancel(_morningDigestBaseId + i);
    }
    if (!IsleUserDefaults.morningNotificationEnabled) return;

    final now = DateTime.now();
    final hour = IsleUserDefaults.morningNotificationHour;
    final minute = IsleUserDefaults.morningNotificationMinute;
    var scheduled = 0;
    for (var offset = 0; offset < _morningDigestDays; offset++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
      final when = DateTime(day.year, day.month, day.day, hour, minute);
      final tzWhen = tz.TZDateTime.from(when, tz.local);
      if (!tzWhen.isAfter(tz.TZDateTime.from(now, tz.local))) continue;
      final body = _buildMorningDigestBody(day);
      try {
        await _plugin.zonedSchedule(
          _morningDigestBaseId + offset,
          '오늘의 차단',
          body,
          tzWhen,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(body),
            ),
            iOS: const DarwinNotificationDetails(),
            macOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: _morningDigestPayload,
        );
        scheduled++;
      } catch (e, st) {
        IsleAppLogService.log('morning digest schedule failed: $e', level: IsleLogLevel.warn, stack: st);
      }
    }
    IsleAppLogService.log('morning digest: scheduled $scheduled days');
  }

  static String _buildMorningDigestBody(DateTime day) {
    final weekday = day.weekday - 1;
    List<BlockSchedule> schedules;
    try {
      schedules = BlockScheduleStore.loadAll()
          .where(
            (s) =>
                s.enabled &&
                s.id != QuickBlockService.presetScheduleId &&
                s.slots.any((sl) => sl.day == weekday),
          )
          .toList();
    } catch (_) {
      schedules = const [];
    }
    if (schedules.isEmpty) return '오늘은 활성화된 차단 스케줄이 없어요.';

    final lines = <String>[];
    for (final s in schedules) {
      final ranges = s.slots
          .where((sl) => sl.day == weekday)
          .map((sl) => '${_hhmm(sl.startMinute)}–${_hhmm(sl.endMinute)}')
          .join(', ');
      String targets;
      try {
        targets = ScheduleDisplayHelper.targetsSummaryDetailed(s);
      } catch (_) {
        targets = '';
      }
      lines.add(targets.isEmpty ? '${s.name} ($ranges)' : '${s.name} ($ranges) — $targets');
    }
    return lines.join('\n');
  }

  static String _hhmm(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  static List<_ScheduleTransition> _collectTransitions({
    required DateTime from,
    required DateTime until,
  }) {
    final schedules = BlockScheduleStore.loadAll().where(
      (s) =>
          s.enabled &&
          s.id != QuickBlockService.presetScheduleId &&
          s.slots.isNotEmpty,
    );
    if (schedules.isEmpty) return [];

    final byInstant = <int, _ScheduleTransition>{};
    final day0 = DateTime(from.year, from.month, from.day);

    for (var offset = 0; offset <= 7; offset++) {
      final day = day0.add(Duration(days: offset));
      final weekday = day.weekday - 1;

      for (final schedule in schedules) {
        for (final slot in schedule.slots) {
          if (slot.day != weekday) continue;
          final start = _slotInstant(day, slot.startMinute);
          final end = _slotEndInstant(day, slot);
          _merge(byInstant, start, from, until, schedule, slot, true, end);
          _merge(byInstant, end, from, until, schedule, slot, false, null);
        }
      }
    }
    return byInstant.values.toList();
  }

  static DateTime _slotInstant(DateTime day, int minute) => DateTime(
        day.year,
        day.month,
        day.day,
        minute ~/ 60,
        minute % 60,
      );

  static DateTime _slotEndInstant(DateTime day, ScheduleSlot slot) {
    if (slot.startMinute <= slot.endMinute) {
      return _slotInstant(day, slot.endMinute);
    }
    final next = day.add(const Duration(days: 1));
    return _slotInstant(next, slot.endMinute);
  }

  /// "차단 시작" 알림 본문 — 스케줄 이름·시간대만으로는 뭘 막는지, 언제까지인지
  /// 몰라서 앱을 열어봐야 했다(2026-07-11 cage 요청: "상세 블락의 내용 및 남은
  /// 시간도 표시되기를 원해"). 대상 요약(`targetsSummaryDetailed`)과 이 슬롯이
  /// 끝나는 시각까지 남은 시간을 같이 붙인다.
  static String _startingNotifBody(
    BlockSchedule schedule,
    ScheduleSlot slot,
    DateTime start,
    DateTime end,
  ) {
    // 이 알림은 슬롯 "시작 시각"에 울리도록 미리 예약해 두는 것이라, 예약하는
    // 시점(rescheduleAll 실행 시점)의 DateTime.now()로 남은 시간을 계산하면
    // 실제 알림이 뜰 때와 값이 안 맞는다 — 반드시 슬롯 시작 시각(start) 기준.
    final left = end.difference(start);
    final remaining = _formatRemaining(left);
    String targets;
    try {
      targets = ScheduleDisplayHelper.targetsSummaryDetailed(schedule);
    } catch (_) {
      targets = '';
    }
    final base = '${schedule.name} · ${slot.label()}';
    if (targets.isEmpty) return remaining == null ? base : '$base · $remaining 후 해제';
    return remaining == null ? '$base\n$targets' : '$base\n$targets · $remaining 후 해제';
  }

  static String? _formatRemaining(Duration left) {
    if (left.isNegative || left.inMinutes < 1) return null;
    final h = left.inHours;
    final m = left.inMinutes % 60;
    if (h <= 0) return '$m분';
    if (m == 0) return '$h시간';
    return '$h시간 $m분';
  }

  static void _merge(
    Map<int, _ScheduleTransition> map,
    DateTime at,
    DateTime from,
    DateTime until,
    BlockSchedule schedule,
    ScheduleSlot slot,
    bool starting,
    DateTime? endsAt,
  ) {
    if (!at.isAfter(from) || !at.isBefore(until)) return;
    final key = at.millisecondsSinceEpoch;
    final label = starting && endsAt != null
        ? _startingNotifBody(schedule, slot, at, endsAt)
        : '${schedule.name} · ${slot.label()}';
    final existing = map[key];
    if (existing == null) {
      map[key] = _ScheduleTransition(
        at: at,
        starting: starting,
        body: label,
      );
      return;
    }
    if (existing.starting != starting) {
      map[key] = _ScheduleTransition(
        at: at,
        starting: starting,
        body: '$label\n---\n${existing.body}',
      );
      return;
    }
    map[key] = _ScheduleTransition(
      at: at,
      starting: starting,
      body: '${existing.body}\n---\n$label',
    );
  }
}

class _ScheduleTransition {
  const _ScheduleTransition({
    required this.at,
    required this.starting,
    required this.body,
  });

  final DateTime at;
  final bool starting;
  final String body;
}
