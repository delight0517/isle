import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../navigation/isle_navigator_key.dart';
import 'isle_app_log_service.dart';
import 'isle_user_defaults.dart';

/// 리포트·기사 생성 완료 등 "지금" 알림 (스케줄 알림은 [ScheduleNotificationService] 담당)
class NotificationService {
  NotificationService._();

  static const _channelId = 'isle_content_ready';
  static const _channelName = '리포트·기사 생성';
  static const _contentReadyBaseId = 43000;
  static const _feedPayload = 'content_ready:/feed';

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _nextId = 0;

  static Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onNotificationTap,
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
      );
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: '관심 표시한 콘텐츠가 글로 만들어지면 알려줍니다',
            importance: Importance.defaultImportance,
          ),
        );
      }
      _initialized = true;
      if (kDebugMode) debugPrint('NotificationService: initialized');
    } catch (e, st) {
      IsleAppLogService.log('NotificationService init failed: $e', level: IsleLogLevel.warn, stack: st);
    }
  }

  /// 새 리포트/기사/다이제스트가 피드에 올라왔을 때 호출
  static Future<void> notifyContentReady({required String title, required String body}) async {
    if (!IsleUserDefaults.contentReportNotificationsEnabled) return;
    await initialize();
    if (!await _hasPermission()) return;

    try {
      await _plugin.show(
        _contentReadyBaseId + (_nextId++ % 200),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        payload: _feedPayload,
      );
    } catch (e, st) {
      IsleAppLogService.log('content ready notif failed: $e', level: IsleLogLevel.warn, stack: st);
    }
  }

  static const _usageChannelId = 'isle_usage_alert';
  static const _usageChannelName = '시청 시간 알림';
  static const _usageNotifBaseId = 44000;

  /// 유튜브 시청 중 남은 시간이 30/50/70/100% 소진됐을 때 알림
  /// (2026-07-13 신규). [threshold]는 사용한 비율(%) — "70% 남았습니다"가
  /// 아니라 "70% 썼습니다" 방향으로 안내한다.
  static Future<void> notifyYoutubeUsageThreshold(int usedPercent) async {
    try {
      await initialize();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _usageChannelId,
            _usageChannelName,
            description: '유튜브 하루/주간 한도의 30·50·70·100% 소진 시 알려줍니다',
            importance: Importance.defaultImportance,
          ),
        );
      }
      if (!await _hasPermission()) return;

      final remaining = (100 - usedPercent).clamp(0, 100);
      final title = usedPercent >= 100 ? '유튜브 시간이 다 됐어요' : '유튜브 시청 시간 알림';
      final body = usedPercent >= 100
          ? '오늘 유튜브 한도를 다 썼어요.'
          : '유튜브 한도 $usedPercent% 사용 — $remaining% 남았습니다.';

      await _plugin.show(
        _usageNotifBaseId + usedPercent,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _usageChannelId,
            _usageChannelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e, st) {
      IsleAppLogService.log('youtube usage notif failed: $e', level: IsleLogLevel.warn, stack: st);
    }
  }

  static Future<bool> _hasPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final opts = await ios?.checkPermissions();
      return opts?.isEnabled == true;
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final mac = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      final opts = await mac?.checkPermissions();
      return opts?.isEnabled == true;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? true;
    }
    return true;
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTap(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  static void _onNotificationTap(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  static void _handlePayload(String? payload) {
    if (payload == null || !payload.startsWith('content_ready:')) return;
    final route = payload.substring('content_ready:'.length);
    final ctx = isleNavigatorKey.currentContext;
    if (ctx == null) return;
    ctx.push(route);
  }
}
