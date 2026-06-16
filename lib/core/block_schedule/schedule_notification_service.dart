import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../services/isle_app_log_service.dart';
import '../services/isle_user_defaults.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'models/schedule_slot.dart';
import 'quick_block_service.dart';

/// 스케줄 슬롯 시작·종료 로컬 알림 (7일·최대 48건, resume 시 재등록)
class ScheduleNotificationService {
  ScheduleNotificationService._();

  static const _channelId = 'isle_schedule_block';
  static const _channelName = '차단 스케줄';
  static const _baseId = 41000;
  static const _maxPending = 48;

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
  }

  /// 마스터·알림 설정·스케줄 변경 후 호출
  static Future<void> rescheduleAll() async {
    if (!IsleUserDefaults.scheduleBlockNotificationsEnabled ||
        !BlockScheduleStore.masterEnabled) {
      await cancelAll();
      return;
    }

    await ensureInitialized();
    final granted = await requestPermission();
    if (!granted) {
      IsleAppLogService.log('schedule notif: permission denied', level: IsleLogLevel.warn);
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
        await _plugin.zonedSchedule(
          _baseId + id,
          e.starting ? '차단 시작' : '차단 해제',
          e.body,
          tzWhen,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
            macOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        id++;
      } catch (e, st) {
        IsleAppLogService.log('schedule notif schedule failed: $e', level: IsleLogLevel.warn, stack: st);
      }
    }
    IsleAppLogService.log('schedule notif: scheduled $id events');
  }

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
          _merge(byInstant, start, from, until, schedule, slot, true);
          _merge(byInstant, end, from, until, schedule, slot, false);
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

  static void _merge(
    Map<int, _ScheduleTransition> map,
    DateTime at,
    DateTime from,
    DateTime until,
    BlockSchedule schedule,
    ScheduleSlot slot,
    bool starting,
  ) {
    if (!at.isAfter(from) || !at.isBefore(until)) return;
    final key = at.millisecondsSinceEpoch;
    final label = '${schedule.name} · ${slot.label()}';
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
        body: '$label 외 ${existing.body}',
      );
      return;
    }
    map[key] = _ScheduleTransition(
      at: at,
      starting: starting,
      body: '${existing.body}, $label',
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
