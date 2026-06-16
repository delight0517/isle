import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../constants/app_release_info.dart';
import '../services/isle_debug_log_service.dart';

/// 렉·무거운 작업 — JSONL (Cursor/Claude 분석용)
/// jank는 메모리+배치 기록 (프레임마다 flush 금지 — 자기 자신이 렉 유발)
class IslePerfLogService {
  IslePerfLogService._();

  static File? _file;
  static File? _mirrorFile;
  static const _maxMemory = 120;
  static final _memory = <Map<String, dynamic>>[];

  static final _pendingLines = <String>[];
  static Timer? _flushTimer;
  static DateTime? _lastJankDiskAt;
  static const _jankDiskCooldownMs = 4000;
  static const _flushDelayMs = 1800;

  static Future<void> ensureReady() async {
    if (_file != null) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      _file = File('${docs.path}/isle_perf.jsonl');
      final mirrorDir = IsleDebugLogService.debugFolderPath;
      if (mirrorDir != null) {
        _mirrorFile = File('$mirrorDir/isle_perf.jsonl');
      }
    } catch (_) {
      _file = null;
      _mirrorFile = null;
    }
  }

  static String get filePath => _file?.path ?? '';

  static List<Map<String, dynamic>> get recentEvents => List.unmodifiable(_memory);

  static Future<void> record(Map<String, dynamic> event) async {
    await ensureReady();
    final enriched = {
      ...event,
      'at': DateTime.now().toUtc().toIso8601String(),
      'version': AppReleaseInfo.label,
      'session_id': _sessionId(),
    };
    _memory.add(enriched);
    if (_memory.length > _maxMemory) _memory.removeAt(0);

    final type = enriched['type'] as String? ?? '';
    final line = '${jsonEncode(enriched)}\n';

    // jank는 디스크에 과다 기록하지 않음 (메모리 요약만)
    if (type == 'frame_jank') {
      final totalMs = (enriched['total_ms'] as num?)?.toInt() ?? 0;
      final now = DateTime.now();
      final last = _lastJankDiskAt;
      final cooldownOk = last == null ||
          now.difference(last).inMilliseconds >= _jankDiskCooldownMs;
      if (!cooldownOk && totalMs < 96) return;
      _lastJankDiskAt = now;
    }

    _pendingLines.add(line);

    if (type == 'severe_lag' || type == 'heavy_work_end' || type == 'ui_stall') {
      await _flushPending();
    } else {
      _scheduleFlush();
    }
  }

  static void _scheduleFlush() {
    _flushTimer ??= Timer(const Duration(milliseconds: _flushDelayMs), () async {
      _flushTimer = null;
      await _flushPending();
    });
  }

  static Future<void> _flushPending() async {
    if (_pendingLines.isEmpty) return;
    final batch = List<String>.from(_pendingLines);
    _pendingLines.clear();
    final payload = batch.join();
    try {
      await _file?.writeAsString(payload, mode: FileMode.append);
      await _mirrorFile?.writeAsString(payload, mode: FileMode.append);
    } catch (_) {}
  }

  static String _sessionId() {
    try {
      return IsleDebugLogService.entries.isNotEmpty
          ? IsleDebugLogService.entries.last.sessionId
          : '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> recordHeavyStart({
    required String taskId,
    required String title,
    int? estimatedMs,
  }) =>
      record({
        'type': 'heavy_work_start',
        'task_id': taskId,
        'title': title,
        if (estimatedMs != null) 'estimated_ms': estimatedMs,
      });

  static Future<void> recordHeavyProgress({
    required String taskId,
    required double progress,
    String? step,
    int? elapsedMs,
  }) =>
      record({
        'type': 'heavy_work_progress',
        'task_id': taskId,
        'progress': progress,
        if (step != null) 'step': step,
        if (elapsedMs != null) 'elapsed_ms': elapsedMs,
      });

  static Future<void> recordHeavyEnd({
    required String taskId,
    required int durationMs,
    required bool success,
    String? error,
    int? jankFramesDuring,
  }) =>
      record({
        'type': 'heavy_work_end',
        'task_id': taskId,
        'duration_ms': durationMs,
        'success': success,
        if (error != null) 'error': error,
        if (jankFramesDuring != null) 'jank_frames_during': jankFramesDuring,
        'severe': durationMs >= 6000,
      });

  static Future<void> recordFrameJank({
    required int totalMs,
    required int buildMs,
    required int rasterMs,
    String? activeTaskId,
  }) =>
      record({
        'type': 'frame_jank',
        'total_ms': totalMs,
        'build_ms': buildMs,
        'raster_ms': rasterMs,
        if (activeTaskId != null && activeTaskId.isNotEmpty) 'active_task_id': activeTaskId,
      });

  static Future<void> recordUiStall({
    required int stallMs,
    String? activeTaskId,
  }) =>
      record({
        'type': 'ui_stall',
        'stall_ms': stallMs,
        if (activeTaskId != null && activeTaskId.isNotEmpty) 'active_task_id': activeTaskId,
        'severe': stallMs >= 1500,
      });

  static Future<void> recordSevereLag({
    required String reason,
    required String taskId,
    required int durationMs,
    required int jankFrames,
    String? detail,
  }) =>
      record({
        'type': 'severe_lag',
        'reason': reason,
        'task_id': taskId,
        'duration_ms': durationMs,
        'jank_frames': jankFrames,
        if (detail != null) 'detail': detail,
      });

  static Future<String> buildCursorExport() async =>
      buildDelayReportForCursor(includeFullTail: true);

  /// 개발자용 — 반복 딜레이·stall·jank 요약 + Cursor 붙여넣기 블록
  static Future<String> buildDelayReportForCursor({
    bool includeFullTail = true,
  }) async {
    await ensureReady();
    final events = await _loadEventsForReport();
    final buf = StringBuffer();

    buf.writeln('=== Isle 딜레이·렉 리포트 (개발자용) ===');
    buf.writeln('Exported: ${DateTime.now().toUtc().toIso8601String()}');
    buf.writeln('Version: ${AppReleaseInfo.label}');
    buf.writeln('Perf file: ${filePath}');
    buf.writeln('Cursor 채팅에 아래 전체를 붙여넣으세요.');
    buf.writeln();

    final summary = _summarizeDelays(events);
    final issueCount = summary.totalIssues;

    buf.writeln('--- 요약 (반복 패턴) ---');
    buf.writeln('이슈 합계: $issueCount건 (jank ${summary.jankCount} · stall ${summary.stallCount} · severe ${summary.severeCount} · 느린작업 ${summary.slowTaskCount})');
    if (summary.maxJankMs > 0) {
      buf.writeln('최대 프레임 지연: ${summary.maxJankMs}ms');
    }
    if (summary.maxStallMs > 0) {
      buf.writeln('최대 UI 멈춤: ${summary.maxStallMs}ms');
    }
    if (summary.repeatedReasons.isNotEmpty) {
      buf.writeln('반복 원인:');
      for (final e in summary.repeatedReasons) {
        buf.writeln('  · ${e.label} ×${e.count}');
      }
    }
    if (summary.activeTasks.isNotEmpty) {
      buf.writeln('관련 작업: ${summary.activeTasks.join(", ")}');
    }
    buf.writeln();

    final severe = events.where((e) {
      final t = e['type'];
      return t == 'severe_lag' ||
          (t == 'heavy_work_end' && e['severe'] == true) ||
          (t == 'ui_stall' && e['severe'] == true);
    }).toList();

    if (severe.isNotEmpty) {
      buf.writeln('--- 심각 이벤트 (${severe.length}) ---');
      for (final e in severe.take(40)) {
        buf.writeln(_formatEventLine(e));
      }
      if (severe.length > 40) {
        buf.writeln('… 외 ${severe.length - 40}건');
      }
      buf.writeln();
    }

    if (includeFullTail) {
      buf.writeln('--- 최근 상세 로그 (최대 200줄) ---');
      try {
        if (_file != null && await _file!.exists()) {
          final lines = await _file!.readAsLines();
          final tail = lines.length > 200 ? lines.sublist(lines.length - 200) : lines;
          for (final l in tail) {
            if (l.trim().isNotEmpty) buf.writeln(l);
          }
        } else {
          for (final e in events.take(120)) {
            buf.writeln(jsonEncode(e));
          }
        }
      } catch (_) {
        for (final e in events.take(120)) {
          buf.writeln(jsonEncode(e));
        }
      }
      buf.writeln();
    }

    buf.writeln('--- HINT ---');
    buf.writeln('Cursor에: "isle_perf.jsonl 딜레이 요약 보고 메인 isolate 부하 줄여줘"');
    return buf.toString();
  }

  /// UI 배지용 — jank·stall·severe·느린 작업 건수
  static Future<int> delayIssueCount() async {
    final events = await _loadEventsForReport();
    return _summarizeDelays(events).totalIssues;
  }

  static Future<List<Map<String, dynamic>>> _loadEventsForReport() async {
    await ensureReady();
    final parsed = <Map<String, dynamic>>[];
    try {
      if (_file != null && await _file!.exists()) {
        final lines = await _file!.readAsLines();
        final tail = lines.length > 400 ? lines.sublist(lines.length - 400) : lines;
        for (final line in tail) {
          if (line.trim().isEmpty) continue;
          try {
            parsed.add(Map<String, dynamic>.from(jsonDecode(line) as Map));
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (parsed.isEmpty) return List.from(_memory);
    // 파일 tail이 우선 — 메모리는 파일에 아직 flush 안 된 최신만 보조
    final fileKeys = parsed.map((e) => '${e['at']}|${e['type']}').toSet();
    for (final m in _memory) {
      final key = '${m['at']}|${m['type']}';
      if (!fileKeys.contains(key)) parsed.add(m);
    }
    return parsed;
  }

  static _DelaySummary _summarizeDelays(List<Map<String, dynamic>> events) {
    var jank = 0;
    var stall = 0;
    var severe = 0;
    var slowTask = 0;
    var maxJank = 0;
    var maxStall = 0;
    final reasonCounts = <String, int>{};
    final taskCounts = <String, int>{};

    for (final e in events) {
      final type = e['type'] as String? ?? '';
      if (type == 'frame_jank') {
        jank++;
        final ms = (e['total_ms'] as num?)?.toInt() ?? 0;
        if (ms > maxJank) maxJank = ms;
        final task = e['active_task_id'] as String?;
        if (task != null && task.isNotEmpty) {
          taskCounts[task] = (taskCounts[task] ?? 0) + 1;
        }
      } else if (type == 'ui_stall') {
        stall++;
        final ms = (e['stall_ms'] as num?)?.toInt() ?? 0;
        if (ms > maxStall) maxStall = ms;
        if (e['severe'] == true) severe++;
      } else if (type == 'severe_lag') {
        severe++;
        final reason = e['reason'] as String? ?? 'unknown';
        reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
        final task = e['task_id'] as String?;
        if (task != null && task.isNotEmpty) {
          taskCounts[task] = (taskCounts[task] ?? 0) + 1;
        }
      } else if (type == 'heavy_work_end' && e['severe'] == true) {
        slowTask++;
        final task = e['task_id'] as String? ?? 'heavy';
        taskCounts[task] = (taskCounts[task] ?? 0) + 1;
      }
    }

    final repeated = reasonCounts.entries
        .map((e) => _RepeatLabel(e.key, e.value))
        .where((e) => e.count >= 2)
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final topTasks = taskCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _DelaySummary(
      jankCount: jank,
      stallCount: stall,
      severeCount: severe,
      slowTaskCount: slowTask,
      maxJankMs: maxJank,
      maxStallMs: maxStall,
      repeatedReasons: repeated,
      activeTasks: topTasks.take(5).map((e) => '${e.key}×${e.value}').toList(),
    );
  }

  static String _formatEventLine(Map<String, dynamic> e) {
    final at = e['at'] ?? '';
    final type = e['type'] ?? '';
    final reason = e['reason'];
    final ms = e['duration_ms'] ?? e['stall_ms'] ?? e['total_ms'];
    final task = e['task_id'] ?? e['active_task_id'];
    return '$at | $type${reason != null ? " | $reason" : ""}${ms != null ? " | ${ms}ms" : ""}${task != null ? " | $task" : ""}';
  }
}

class _DelaySummary {
  const _DelaySummary({
    required this.jankCount,
    required this.stallCount,
    required this.severeCount,
    required this.slowTaskCount,
    required this.maxJankMs,
    required this.maxStallMs,
    required this.repeatedReasons,
    required this.activeTasks,
  });

  final int jankCount;
  final int stallCount;
  final int severeCount;
  final int slowTaskCount;
  final int maxJankMs;
  final int maxStallMs;
  final List<_RepeatLabel> repeatedReasons;
  final List<String> activeTasks;

  int get totalIssues => jankCount + stallCount + severeCount + slowTaskCount;
}

class _RepeatLabel {
  const _RepeatLabel(this.label, this.count);
  final String label;
  final int count;
}
