import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_release_info.dart';

/// 크래시·에러 로그 — 앱 Documents + Mac `Documents/Isle Debug` 미러, 재시작 후에도 유지
class IsleDebugLogService {
  IsleDebugLogService._();

  static final List<IsleLogEntry> _memory = [];
  static const _maxMemory = 400;
  static const _maxTimelineFile = 800;

  static File? _logFile;
  static File? _mirrorLogFile;
  static File? _timelineFile;
  static File? _sessionFlagFile;
  static Directory? _debugDir;
  static String _sessionId = '';
  static final _listeners = <void Function(IsleLogEntry)>[];
  static final _crashListeners = <void Function(CrashReport)>[];

  static List<IsleLogEntry> get entries => List.unmodifiable(_memory);

  static List<CrashReport> _crashes = [];

  /// UI·배너·보내기 — 노이즈·수정된 구버전 오류 제외
  static List<CrashReport> get crashHistory => List.unmodifiable(_crashes);

  static int get ignoredCrashCount => _ignoredCrashCount;
  static int _ignoredCrashCount = 0;

  static String? get debugFolderPath => _debugDir?.path;

  static String get logFilePath => _logFile?.path ?? '';

  static void addListener(void Function(IsleLogEntry) fn) => _listeners.add(fn);

  static void removeListener(void Function(IsleLogEntry) fn) => _listeners.remove(fn);

  static void addCrashListener(void Function(CrashReport) fn) => _crashListeners.add(fn);

  static void removeCrashListener(void Function(CrashReport) fn) => _crashListeners.remove(fn);

  /// `main()` — Hive 전, 핸들러 설치 전
  static Future<void> bootstrap() async {
    await _initPaths();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    await _loadTimelineFromDisk();
    _pruneLoadedCrashes();
    await _loadLogTailFromDisk();
    await _detectUncleanShutdown();
    await _writeSessionFlag();
    log('Session start $_sessionId', level: IsleLogLevel.info);
  }

  static Future<void> _initPaths() async {
    final docs = await getApplicationDocumentsDirectory();
    _logFile = File('${docs.path}/isle_debug.log');
    _timelineFile = File('${docs.path}/isle_timeline.jsonl');
    _sessionFlagFile = File('${docs.path}/session_active.flag');

    _debugDir = await _resolveMirrorDirectory();
    if (_debugDir != null) {
      if (!await _debugDir!.exists()) {
        await _debugDir!.create(recursive: true);
      }
      _mirrorLogFile = File('${_debugDir!.path}/isle_debug.log');
    }
  }

  static Future<Directory?> _resolveMirrorDirectory() async {
    if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory('$home/Documents/Isle Debug');
      }
    }
    if (Platform.isWindows) {
      final profile = Platform.environment['USERPROFILE'];
      if (profile != null && profile.isNotEmpty) {
        return Directory('$profile\\Documents\\Isle Debug');
      }
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      return Directory('${docs.path}/Isle Debug');
    } catch (_) {
      return null;
    }
  }

  static Future<void> _detectUncleanShutdown() async {
    final flag = _sessionFlagFile;
    if (flag == null || !await flag.exists()) return;
    final prev = await flag.readAsString();
    await recordCrash(
      kind: 'unclean_shutdown',
      message: '이전 실행이 정상 종료되지 않았습니다 (크래시·강제 종료 가능)',
      detail: prev.trim().isEmpty ? null : prev,
    );
  }

  static Future<void> _writeSessionFlag() async {
    final flag = _sessionFlagFile;
    if (flag == null) return;
    final payload = jsonEncode({
      'session_id': _sessionId,
      'started_at': DateTime.now().toIso8601String(),
      'version': AppReleaseInfo.label,
    });
    await flag.writeAsString(payload);
  }

  /// 백그라운드·정상 종료 시
  static Future<void> markCleanShutdown() async {
    log('Session clean pause', level: IsleLogLevel.debug);
    final flag = _sessionFlagFile;
    if (flag == null) return;
    try {
      if (await flag.exists()) await flag.delete();
    } on FileSystemException {
      // 이미 삭제됨·동시 pause — 크래시로 올리지 않음
    }
  }

  /// 알려진 노이즈·이미 패치된 스택 — 크래시 배너·타임라인에서 제외
  static bool shouldIgnoreCrash({
    required String kind,
    required String message,
    String? stack,
  }) {
    final msg = message.toLowerCase();
    final st = stack ?? '';

    if (msg.contains('googlefonts') ||
        msg.contains('notosanskr') ||
        msg.contains('allowruntimefetching is false') ||
        msg.contains('librebaskerville') ||
        msg.contains('jetbrainsmono')) {
      return true;
    }

    if (kind == 'unclean_shutdown') return true;

    if (msg.contains('pathnotfoundexception') &&
        (msg.contains('session_active.flag') ||
            msg.contains('isle_state_checkpoint') ||
            msg.contains('cannot delete file') ||
            msg.contains('cannot rename file'))) {
      return true;
    }

    if (msg.contains('sharepositionorigin') && msg.contains('argument must be set')) {
      return true;
    }

    if (msg.contains('cannot use "ref" after the widget was disposed') &&
        st.contains('web_explorer_screen')) {
      return true;
    }

    if ((kind == 'error_widget' || kind == 'flutter_error') &&
        msg.contains('bad state: no element') &&
        st.contains('schedule_app_targets_section')) {
      return true;
    }

    return false;
  }

  static String _crashFingerprint(String kind, String message) =>
      '$kind|${message.length > 120 ? message.substring(0, 120) : message}';

  static void _pruneLoadedCrashes() {
    final kept = <CrashReport>[];
    final seen = <String>{};
    var dropped = 0;
    for (final c in _crashes) {
      if (shouldIgnoreCrash(kind: c.kind, message: c.message, stack: c.stack)) {
        dropped++;
        continue;
      }
      final fp = _crashFingerprint(c.kind, c.message);
      if (seen.contains(fp)) {
        dropped++;
        continue;
      }
      seen.add(fp);
      kept.add(c);
    }
    if (dropped > 0) {
      _crashes = kept;
      _ignoredCrashCount = dropped;
      unawaited(_rewriteTimelineFromCrashes());
      log('Pruned $dropped stale/noise crash entries', level: IsleLogLevel.info);
    }
  }

  static Future<void> _rewriteTimelineFromCrashes() async {
    try {
      final lines = <String>[];
      for (final c in _crashes.reversed) {
        lines.add(jsonEncode(c.toTimelineJson()));
      }
      final body = lines.isEmpty ? '' : '${lines.join('\n')}\n';
      if (_timelineFile != null) {
        await _timelineFile!.writeAsString(body, flush: true);
      }
      final mirror = _debugDir != null ? File('${_debugDir!.path}/isle_timeline.jsonl') : null;
      if (mirror != null) {
        await mirror.writeAsString(body, flush: true);
      }
    } catch (_) {}
  }

  static Future<void> recordCrash({
    required String kind,
    required String message,
    String? detail,
    StackTrace? stack,
  }) async {
    if (shouldIgnoreCrash(kind: kind, message: message, stack: stack?.toString())) {
      _ignoredCrashCount++;
      return;
    }
    final fp = _crashFingerprint(kind, message);
    if (_crashes.any((c) => _crashFingerprint(c.kind, c.message) == fp)) {
      return;
    }
    final at = DateTime.now();
    final report = CrashReport(
      id: '${at.millisecondsSinceEpoch}',
      at: at,
      kind: kind,
      message: message,
      detail: detail,
      stack: stack?.toString(),
      versionTag: AppReleaseInfo.label,
      sessionId: _sessionId,
    );
    _crashes.insert(0, report);
    if (_crashes.length > 50) _crashes.length = 50;
    for (final fn in List<void Function(CrashReport)>.from(_crashListeners)) {
      fn(report);
    }
    await _appendTimeline(report.toTimelineJson());
    log(
      'CRASH[$kind] $message',
      level: IsleLogLevel.error,
      error: detail,
      stack: stack,
    );
  }

  static void log(
    String message, {
    IsleLogLevel level = IsleLogLevel.info,
    Object? error,
    StackTrace? stack,
  }) {
    final at = DateTime.now();
    final entry = IsleLogEntry(
      at: at,
      appName: AppReleaseInfo.appName,
      versionTag: AppReleaseInfo.label,
      level: level,
      message: message,
      error: error?.toString(),
      stack: stack?.toString(),
      sessionId: _sessionId,
    );
    final line = entry.formatLine();

    if (kDebugMode) debugPrint(line);

    _memory.add(entry);
    if (_memory.length > _maxMemory) _memory.removeAt(0);

    for (final fn in _listeners) {
      fn(entry);
    }

    unawaited(_persistLine(line));
    if (level == IsleLogLevel.error || level == IsleLogLevel.warn) {
      unawaited(_appendTimeline({
        'type': 'log',
        'level': level.name,
        'at': at.toIso8601String(),
        'message': message,
        'version': AppReleaseInfo.label,
        'session_id': _sessionId,
      }));
    }
  }

  static Future<void> _persistLine(String line) async {
    try {
      if (_logFile != null) {
        await _logFile!.writeAsString('$line\n', mode: FileMode.append, flush: true);
      }
      if (_mirrorLogFile != null) {
        await _mirrorLogFile!.writeAsString('$line\n', mode: FileMode.append, flush: true);
      }
    } catch (_) {
      // 2차: mirror만 실패해도 앱은 계속
    }
  }

  static Future<void> _appendTimeline(Map<String, dynamic> event) async {
    try {
      final line = jsonEncode(event);
      if (_timelineFile != null) {
        await _timelineFile!.writeAsString('$line\n', mode: FileMode.append, flush: true);
      }
      final mirror = _debugDir != null ? File('${_debugDir!.path}/isle_timeline.jsonl') : null;
      if (mirror != null) {
        await mirror.writeAsString('$line\n', mode: FileMode.append, flush: true);
      }
    } catch (_) {}
  }

  static Future<void> _loadLogTailFromDisk() async {
    try {
      final f = _logFile;
      if (f == null || !await f.exists()) return;
      final lines = await f.readAsLines();
      final tail = lines.length > 150 ? lines.sublist(lines.length - 150) : lines;
      for (final line in tail) {
        if (line.trim().isEmpty) continue;
        _memory.add(IsleLogEntry.parseLine(line));
      }
    } catch (_) {}
  }

  static Future<void> _loadTimelineFromDisk() async {
    try {
      final f = _timelineFile;
      if (f == null || !await f.exists()) return;
      final lines = await f.readAsLines();
      final tail = lines.length > _maxTimelineFile
          ? lines.sublist(lines.length - _maxTimelineFile)
          : lines;
      _crashes = [];
      for (final line in tail.reversed) {
        if (line.trim().isEmpty) continue;
        try {
          final j = jsonDecode(line) as Map<String, dynamic>;
          if (j['type'] == 'crash') {
            _crashes.insert(0, CrashReport.fromJson(j));
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<String> buildCopyAllText() async {
    final buf = StringBuffer();
    buf.writeln('=== Isle Debug Export ===');
    buf.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buf.writeln('Version: ${AppReleaseInfo.label}');
    buf.writeln('Session: $_sessionId');
    buf.writeln('Log file: ${logFilePath}');
    buf.writeln('Debug folder: ${debugFolderPath ?? "n/a"}');
    buf.writeln();

    if (_crashes.isNotEmpty) {
      buf.writeln('--- CRASH HISTORY (${_crashes.length} actionable) ---');
      for (final c in _crashes) {
        buf.writeln(c.formatBlock());
        buf.writeln('---');
      }
    } else if (_ignoredCrashCount > 0) {
      buf.writeln(
        '--- CRASH HISTORY: 비어 있음 (노이즈·구버전 ${_ignoredCrashCount}건은 표시하지 않음) ---',
      );
    }

    buf.writeln('--- LOG (${_memory.length} in memory) ---');
    try {
      if (_logFile != null && await _logFile!.exists()) {
        final all = await _logFile!.readAsString();
        buf.writeln(all);
      } else {
        for (final e in _memory) {
          buf.writeln(e.formatLine());
        }
      }
    } catch (_) {
      for (final e in _memory) {
        buf.writeln(e.formatLine());
      }
    }
    return buf.toString();
  }

  static Future<void> clearAllLogs() async {
    _memory.clear();
    _crashes.clear();
    try {
      if (_logFile != null && await _logFile!.exists()) await _logFile!.delete();
      if (_mirrorLogFile != null && await _mirrorLogFile!.exists()) {
        await _mirrorLogFile!.delete();
      }
      if (_timelineFile != null && await _timelineFile!.exists()) {
        await _timelineFile!.delete();
      }
      final mirrorTl = _debugDir != null ? File('${_debugDir!.path}/isle_timeline.jsonl') : null;
      if (mirrorTl != null && await mirrorTl.exists()) await mirrorTl.delete();
    } catch (_) {}
    log('Logs cleared by user', level: IsleLogLevel.warn);
  }

  static void installGlobalHandlers() {
    final prevFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      unawaited(recordCrash(
        kind: 'flutter_error',
        message: details.exceptionAsString(),
        detail: details.context?.toString(),
        stack: details.stack,
      ));
      if (prevFlutter != null) {
        prevFlutter(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(recordCrash(
        kind: 'async_error',
        message: error.toString(),
        stack: stack,
      ));
      return true;
    };
  }
}

class CrashReport {
  const CrashReport({
    required this.id,
    required this.at,
    required this.kind,
    required this.message,
    this.detail,
    this.stack,
    required this.versionTag,
    required this.sessionId,
  });

  final String id;
  final DateTime at;
  final String kind;
  final String message;
  final String? detail;
  final String? stack;
  final String versionTag;
  final String sessionId;

  Map<String, dynamic> toTimelineJson() => {
        'type': 'crash',
        'id': id,
        'at': at.toIso8601String(),
        'kind': kind,
        'message': message,
        'detail': detail,
        'stack': stack,
        'version': versionTag,
        'session_id': sessionId,
      };

  factory CrashReport.fromJson(Map<String, dynamic> j) => CrashReport(
        id: j['id'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        kind: j['kind'] as String? ?? 'unknown',
        message: j['message'] as String? ?? '',
        detail: j['detail'] as String?,
        stack: j['stack'] as String?,
        versionTag: j['version'] as String? ?? AppReleaseInfo.label,
        sessionId: j['session_id'] as String? ?? '',
      );

  String formatBlock() {
    final local = at.toLocal();
    final ts =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}.${local.millisecond.toString().padLeft(3, '0')}';
    final buf = StringBuffer('[$ts] [$versionTag] CRASH $kind\n$message');
    if (detail != null && detail!.isNotEmpty) buf.write('\n$detail');
    if (stack != null && stack!.isNotEmpty) buf.write('\n$stack');
    return buf.toString();
  }
}

/// [IsleAppLogService] 와 동일 타입 — 하위 호환
enum IsleLogLevel { debug, info, warn, error }

class IsleLogEntry {
  final DateTime at;
  final String appName;
  final String versionTag;
  final IsleLogLevel level;
  final String message;
  final String? error;
  final String? stack;
  final String sessionId;

  const IsleLogEntry({
    required this.at,
    required this.appName,
    required this.versionTag,
    required this.level,
    required this.message,
    this.error,
    this.stack,
    this.sessionId = '',
  });

  String formatLine() {
    final local = at.toLocal();
    final ts =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}T'
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}.${local.millisecond.toString().padLeft(3, '0')}';
    final buf = StringBuffer(
      '[$ts] [$appName] [$versionTag] [${level.name.toUpperCase()}]',
    );
    if (sessionId.isNotEmpty) buf.write(' [sess:$sessionId]');
    buf.write(' $message');
    if (error != null) buf.write(' | $error');
    return buf.toString();
  }

  static IsleLogEntry parseLine(String line) {
    return IsleLogEntry(
      at: DateTime.now(),
      appName: AppReleaseInfo.appName,
      versionTag: AppReleaseInfo.label,
      level: line.contains('[ERROR]')
          ? IsleLogLevel.error
          : line.contains('[WARN]')
              ? IsleLogLevel.warn
              : IsleLogLevel.info,
      message: line,
    );
  }
}
