export 'isle_debug_log_service.dart' show CrashReport, IsleLogEntry, IsleLogLevel;

import 'isle_debug_log_service.dart';

/// 인앱·파일 로그 — [IsleDebugLogService] 래퍼 (하위 호환)
class IsleAppLogService {
  IsleAppLogService._();

  static List<IsleLogEntry> get recent => IsleDebugLogService.entries;

  static void addListener(void Function(IsleLogEntry) fn) =>
      IsleDebugLogService.addListener(fn);

  static void removeListener(void Function(IsleLogEntry) fn) {
    IsleDebugLogService.removeListener(fn);
  }

  @Deprecated('Use IsleDebugLogService.bootstrap in main')
  static Future<void> ensureFileReady() async {}

  static void log(
    String message, {
    IsleLogLevel level = IsleLogLevel.info,
    Object? error,
    StackTrace? stack,
  }) =>
      IsleDebugLogService.log(message, level: level, error: error, stack: stack);

  static void installGlobalHandlers() => IsleDebugLogService.installGlobalHandlers();
}
