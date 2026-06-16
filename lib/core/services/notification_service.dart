import 'package:flutter/foundation.dart';

/// 로컬/푸시 알림 Phase 2 예약
class NotificationService {
  NotificationService._();

  static Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('NotificationService: Phase 1 no-op');
    }
  }
}
