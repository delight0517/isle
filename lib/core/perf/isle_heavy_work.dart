import 'dart:async';

import '../services/isle_app_log_service.dart';
import 'isle_frame_watchdog.dart';
import 'isle_heavy_work_controller.dart';
import 'isle_heavy_work_reporter.dart';
import 'isle_perf_log_service.dart';

/// 무거운 작업 — 진행 UI + perf JSONL
class IsleHeavyWork {
  IsleHeavyWork._();

  static Future<T> run<T>({
    required String taskId,
    required String userTitle,
    required String userWhy,
    required Future<T> Function(IsleHeavyWorkReporter reporter) work,
    int estimatedMs = 4000,
  }) async {
    final ctrl = IsleHeavyWorkController.instance;
    final started = DateTime.now();
    final jankBefore = IsleFrameWatchdog.jankCountInWindow;

    ctrl.beginTask(
      taskId: taskId,
      title: userTitle,
      why: userWhy,
      estimatedMs: estimatedMs,
    );
    await IslePerfLogService.recordHeavyStart(
      taskId: taskId,
      title: userTitle,
      estimatedMs: estimatedMs,
    );

    final reporter = IsleHeavyWorkReporter((progress, {stepLabel}) {
      if (progress >= 0) {
        ctrl.updateProgress(progress, stepLabel: stepLabel);
      } else if (stepLabel != null) {
        ctrl.updateProgress(ctrl.snapshot.progress, stepLabel: stepLabel);
      }
      unawaited(
        IslePerfLogService.recordHeavyProgress(
          taskId: taskId,
          progress: progress >= 0 ? progress : ctrl.snapshot.progress,
          step: stepLabel,
          elapsedMs: DateTime.now().difference(started).inMilliseconds,
        ),
      );
    });

    try {
      final result = await work(reporter);
      reporter.progress(1, stepLabel: '완료');
      final ms = DateTime.now().difference(started).inMilliseconds;
      final jankDuring = IsleFrameWatchdog.jankCountInWindow - jankBefore;
      await IslePerfLogService.recordHeavyEnd(
        taskId: taskId,
        durationMs: ms,
        success: true,
        jankFramesDuring: jankDuring,
      );
      if (ms >= 6000 || jankDuring >= 15) {
        await IslePerfLogService.recordSevereLag(
          reason: 'heavy_work_slow',
          taskId: taskId,
          durationMs: ms,
          jankFrames: jankDuring,
          detail: userTitle,
        );
        IsleAppLogService.log(
          'PERF severe lag task=$taskId ${ms}ms jank=$jankDuring',
          level: IsleLogLevel.warn,
        );
      }
      return result;
    } catch (e, st) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      await IslePerfLogService.recordHeavyEnd(
        taskId: taskId,
        durationMs: ms,
        success: false,
        error: e.toString(),
      );
      IsleAppLogService.log(
        'PERF task failed $taskId: $e',
        level: IsleLogLevel.error,
        error: e,
        stack: st,
      );
      rethrow;
    } finally {
      ctrl.endTask(taskId);
    }
  }
}
