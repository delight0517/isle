import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../services/isle_app_log_service.dart';
import 'isle_heavy_work_controller.dart';
import 'isle_perf_log_service.dart';

/// UI 프레임 지연·스톨 자동 감지 [Volt]
/// 자동 감지는 **파일 로그만** — 전면 오버레이는 무거운 작업(beginTask) 때만.
class IsleFrameWatchdog {
  IsleFrameWatchdog._();

  static bool _installed = false;
  static DateTime? _lastFrameAt;
  static Timer? _stallTimer;
  static int _jankInWindow = 0;
  static DateTime _windowStart = DateTime.now();
  static DateTime? _lastJankLogAt;

  static const _jankFrameMs = 48;
  static const _stallCheckMs = 500;
  static const _stallThresholdMs = 2000;
  static const _jankLogCooldownMs = 15000;

  static int get jankCountInWindow => _jankInWindow;

  static void install() {
    if (_installed) return;
    _installed = true;
    _lastFrameAt = DateTime.now();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _stallTimer = Timer.periodic(
      const Duration(milliseconds: _stallCheckMs),
      (_) => _checkStall(),
    );
    IsleAppLogService.log('IsleFrameWatchdog installed (log-only jank)');
  }

  static void _onTimings(List<FrameTiming> timings) {
    _lastFrameAt = DateTime.now();
    final activeTask = IsleHeavyWorkController.instance.snapshot.taskId;

    for (final t in timings) {
      final buildMs = t.buildDuration.inMilliseconds;
      final rasterMs = t.rasterDuration.inMilliseconds;
      final totalMs = t.totalSpan.inMilliseconds;
      if (totalMs < _jankFrameMs) continue;

      _jankInWindow++;
      final now = DateTime.now();
      if (now.difference(_windowStart).inSeconds >= 2) {
        _windowStart = now;
        _jankInWindow = 1;
      }

      // 심각 프레임만 개별 기록 (나머지는 burst/severe로 집계)
      if (totalMs >= 72 || _jankInWindow % 6 == 0) {
        unawaited(
          IslePerfLogService.recordFrameJank(
            totalMs: totalMs,
            buildMs: buildMs,
            rasterMs: rasterMs,
            activeTaskId: activeTask.isEmpty ? null : activeTask,
          ),
        );
      }

      if (_jankInWindow >= 8) {
        _maybeLogJankBurst(
          reason: 'frame_jank_burst',
          taskId: activeTask.isEmpty ? 'ui' : activeTask,
          jankFrames: _jankInWindow,
          durationMs: now.difference(_windowStart).inMilliseconds,
        );
      }
    }
  }

  static void _checkStall() {
    final last = _lastFrameAt;
    if (last == null) return;
    final stallMs = DateTime.now().difference(last).inMilliseconds;
    if (stallMs < _stallThresholdMs) return;

    final snap = IsleHeavyWorkController.instance.snapshot;
    final taskId = snap.taskId.isEmpty ? 'ui_stall' : snap.taskId;

    unawaited(
      IslePerfLogService.recordUiStall(
        stallMs: stallMs,
        activeTaskId: snap.taskId.isEmpty ? null : snap.taskId,
      ),
    );

    if (stallMs >= 3000) {
      _maybeLogJankBurst(
        reason: 'ui_stall',
        taskId: taskId,
        jankFrames: _jankInWindow,
        durationMs: stallMs,
        detail: snap.title.isEmpty ? 'no_active_task' : snap.title,
      );
    }
  }

  static void _maybeLogJankBurst({
    required String reason,
    required String taskId,
    required int jankFrames,
    required int durationMs,
    String? detail,
  }) {
    final now = DateTime.now();
    final last = _lastJankLogAt;
    if (last != null &&
        now.difference(last).inMilliseconds < _jankLogCooldownMs) {
      return;
    }
    _lastJankLogAt = now;

    unawaited(
      IslePerfLogService.recordSevereLag(
        reason: reason,
        taskId: taskId,
        durationMs: durationMs,
        jankFrames: jankFrames,
        detail: detail,
      ),
    );

    // 개발 빌드에서만 짧은 힌트 오버레이 (릴리스는 로그만 — 사용 방해 금지)
    if (kDebugMode && !IsleHeavyWorkController.instance.snapshot.visible) {
      IsleHeavyWorkController.instance.showJankOverlay(
        jankFrames: jankFrames,
        relatedTaskId: taskId,
      );
    }
  }

  static void dispose() {
    _stallTimer?.cancel();
    _stallTimer = null;
    _installed = false;
  }
}
