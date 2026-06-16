import 'package:flutter/foundation.dart';

/// 전역 — 무거운 작업·렉 오버레이 상태
class IsleHeavyWorkSnapshot {
  const IsleHeavyWorkSnapshot({
    this.taskId = '',
    this.title = '',
    this.why = '',
    this.stepLabel = '',
    this.progress = 0,
    this.startedAt,
    this.estimatedTotalMs = 0,
    this.visible = false,
    this.severe = false,
    this.fromJank = false,
    this.jankFrameCount = 0,
  });

  final String taskId;
  final String title;
  final String why;
  final String stepLabel;
  final double progress;
  final DateTime? startedAt;
  final int estimatedTotalMs;
  final bool visible;
  final bool severe;
  final bool fromJank;
  final int jankFrameCount;

  int get remainingPercent {
    if (progress <= 0) return 99;
    if (progress >= 1) return 0;
    return ((1 - progress) * 100).round().clamp(0, 99);
  }

  int? get estimatedRemainingSec {
    if (estimatedTotalMs <= 0 || progress <= 0) return null;
    final left = ((1 - progress) * estimatedTotalMs / 1000).round();
    return left.clamp(1, 999);
  }

  int get elapsedMs {
    final s = startedAt;
    if (s == null) return 0;
    return DateTime.now().difference(s).inMilliseconds;
  }

  IsleHeavyWorkSnapshot copyWith({
    String? taskId,
    String? title,
    String? why,
    String? stepLabel,
    double? progress,
    DateTime? startedAt,
    int? estimatedTotalMs,
    bool? visible,
    bool? severe,
    bool? fromJank,
    int? jankFrameCount,
  }) =>
      IsleHeavyWorkSnapshot(
        taskId: taskId ?? this.taskId,
        title: title ?? this.title,
        why: why ?? this.why,
        stepLabel: stepLabel ?? this.stepLabel,
        progress: progress ?? this.progress,
        startedAt: startedAt ?? this.startedAt,
        estimatedTotalMs: estimatedTotalMs ?? this.estimatedTotalMs,
        visible: visible ?? this.visible,
        severe: severe ?? this.severe,
        fromJank: fromJank ?? this.fromJank,
        jankFrameCount: jankFrameCount ?? this.jankFrameCount,
      );
}

class IsleHeavyWorkController extends ChangeNotifier {
  IsleHeavyWorkController._();

  static final instance = IsleHeavyWorkController._();

  IsleHeavyWorkSnapshot _snap = const IsleHeavyWorkSnapshot();
  int _activeTasks = 0;

  IsleHeavyWorkSnapshot get snapshot => _snap;

  void beginTask({
    required String taskId,
    required String title,
    required String why,
    int estimatedMs = 4000,
  }) {
    _activeTasks++;
    _snap = IsleHeavyWorkSnapshot(
      taskId: taskId,
      title: title,
      why: why,
      progress: 0.02,
      startedAt: DateTime.now(),
      estimatedTotalMs: estimatedMs,
      visible: true,
      severe: false,
      fromJank: false,
    );
    notifyListeners();
  }

  void updateProgress(double progress, {String? stepLabel}) {
    if (_activeTasks <= 0) return;
    _snap = _snap.copyWith(
      progress: progress >= 0 ? progress : _snap.progress,
      stepLabel: stepLabel ?? _snap.stepLabel,
      visible: true,
      severe: _snap.elapsedMs > 6000 || progress > 0 && _snap.elapsedMs > 8000,
    );
    notifyListeners();
  }

  void endTask(String taskId) {
    if (_activeTasks > 0) _activeTasks--;
    if (_activeTasks > 0) return;
    if (_snap.fromJank) {
      _snap = _snap.copyWith(visible: false, progress: 1);
      notifyListeners();
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (_activeTasks == 0 && !_snap.fromJank) {
          _snap = const IsleHeavyWorkSnapshot();
          notifyListeners();
        } else if (_activeTasks == 0) {
          _snap = const IsleHeavyWorkSnapshot();
          notifyListeners();
        }
      });
      return;
    }
    _snap = const IsleHeavyWorkSnapshot();
    notifyListeners();
  }

  void showJankOverlay({
    required int jankFrames,
    String? relatedTaskId,
  }) {
    // 릴리스/프로필: 호출돼도 전면 차단하지 않음 (watchdog가 debug에서만 호출)
    if (!kDebugMode) return;

    if (_activeTasks > 0) {
      _snap = _snap.copyWith(
        jankFrameCount: jankFrames,
        severe: jankFrames >= 8 || _snap.elapsedMs > 5000,
        visible: true,
      );
      notifyListeners();
      return;
    }
    _snap = IsleHeavyWorkSnapshot(
      taskId: relatedTaskId ?? 'ui_jank',
      title: '화면을 따라잡는 중',
      why: '방금 무거운 연산이 UI를 잠깐 멈추게 했어요. '
          '원인을 기록했으니 다음 업데이트에서 줄일 수 있어요.',
      stepLabel: '프레임 지연 ${jankFrames}회 감지',
      progress: 0.35,
      startedAt: DateTime.now(),
      estimatedTotalMs: 2500,
      visible: true,
      severe: jankFrames >= 12,
      fromJank: true,
      jankFrameCount: jankFrames,
    );
    notifyListeners();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (_activeTasks == 0 && _snap.fromJank) {
        _snap = const IsleHeavyWorkSnapshot();
        notifyListeners();
      }
    });
  }
}
