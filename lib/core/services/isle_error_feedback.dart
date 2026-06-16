import 'package:flutter/material.dart';

import 'isle_app_log_service.dart';

/// 사용자 메시지 + 앱 로그 (Cursor·실기기 디버그용)
class IsleErrorFeedback {
  IsleErrorFeedback._();

  static String friendly(Object error) {
    final raw = error.toString();
    if (raw.contains('Google 로그인')) return 'Google 로그인이 필요해요.';
    if (raw.contains('sign_in') || raw.contains('SignIn')) {
      return 'Google 로그인이 취소되었거나 실패했어요.';
    }
    if (raw.contains('SocketException') || raw.contains('Connection')) {
      return '네트워크 연결을 확인해 주세요.';
    }
    if (raw.contains('401') || raw.contains('403')) {
      return 'YouTube API 권한이 없어요. 다시 로그인해 주세요.';
    }
    return raw
        .replaceFirst('Bad state: ', '')
        .replaceFirst('StateError: ', '')
        .replaceFirst('Exception: ', '')
        .trim();
  }

  static void log(String tag, Object error, {StackTrace? stack}) {
    IsleAppLogService.log(
      '$tag: $error',
      level: IsleLogLevel.warn,
      stack: stack,
    );
  }

  static void snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static void logAndSnack(
    BuildContext context, {
    required String tag,
    required Object error,
    String? userMessage,
    StackTrace? stack,
  }) {
    log(tag, error, stack: stack);
    snack(context, userMessage ?? friendly(error));
  }
}
