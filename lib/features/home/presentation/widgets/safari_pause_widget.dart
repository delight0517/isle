import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/platform/platform_block_intent.dart';
import '../../../../core/intervention/safari_pause_service.dart';
import '../../../../core/platform/isle_apple_platform.dart';

/// Safari·앱 쉴드 N분 임시 해제 UI.
/// [alwaysOn] && [hasApps] 일 때만 렌더, iOS 전용.
class SafariPauseWidget extends StatefulWidget {
  const SafariPauseWidget({
    super.key,
    required this.alwaysOn,
    required this.hasApps,
  });

  final bool alwaysOn;
  final bool hasApps;

  @override
  State<SafariPauseWidget> createState() => _SafariPauseWidgetState();
}

class _SafariPauseWidgetState extends State<SafariPauseWidget> {
  Timer? _tick;
  bool _busy = false;

  bool get _shieldActive => widget.alwaysOn && widget.hasApps;

  @override
  void initState() {
    super.initState();
    if (_shieldActive) _startTick();
  }

  @override
  void didUpdateWidget(SafariPauseWidget old) {
    super.didUpdateWidget(old);
    if (_shieldActive && _tick == null) _startTick();
    if (!_shieldActive) _stopTick();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTick() {
    _tick?.cancel();
    _tick = null;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmt(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_shieldActive || !IsleApplePlatform.isNativeBlockHost) {
      return const SizedBox.shrink();
    }

    if (SafariPauseService.isPaused) {
      final remaining = SafariPauseService.remainingSeconds;
      return _PausedBanner(
        timeLabel: _fmt(remaining),
        busy: _busy,
        onCancel: () => _run(SafariPauseService.cancelPause),
      );
    }

    return _PauseChips(
      busy: _busy,
      onPause: (min) => _run(() => SafariPauseService.pauseFor(min)),
    );
  }
}

// ──────────────────────────────────────────────────────── 내부 위젯 ──

class _PauseChips extends StatelessWidget {
  const _PauseChips({required this.busy, required this.onPause});

  final bool busy;
  final void Function(int minutes) onPause;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: IsleColors.ocean100.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_open_outlined, size: 16, color: IsleColors.ocean700),
              const SizedBox(width: 6),
              Text(
                PlatformBlockCopy.appShieldPauseTitle,
                style: IsleText.body().copyWith(
                  fontWeight: FontWeight.w700,
                  color: IsleColors.ocean900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            PlatformBlockCopy.appShieldPauseSubtitle,
            style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.3),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final min in [5, 10, 15]) ...[
                if (min > 5) const SizedBox(width: 8),
                _DurationChip(
                  minutes: min,
                  busy: busy,
                  onTap: () => onPause(min),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.minutes,
    required this.busy,
    required this.onTap,
  });

  final int minutes;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: IsleColors.ocean700.withValues(alpha: busy ? 0.04 : 0.09),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: IsleColors.ocean500.withValues(alpha: busy ? 0.2 : 0.45),
            ),
          ),
          child: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  '$minutes분',
                  style: IsleText.caption(color: IsleColors.ocean700).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _PausedBanner extends StatelessWidget {
  const _PausedBanner({
    required this.timeLabel,
    required this.busy,
    required this.onCancel,
  });

  final String timeLabel;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 20, color: Color(0xFFE65100)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PlatformBlockCopy.appShieldPausedBannerTitle,
                  style: IsleText.body().copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE65100),
                  ),
                ),
                Text(
                  '$timeLabel 후 자동 재잠금',
                  style: IsleText.caption(color: const Color(0xFFBF360C)).copyWith(height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: busy ? null : onCancel,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE65100),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: const BorderSide(color: Color(0xFFFF8A65), width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE65100)),
                  )
                : const Text(
                    '즉시 재잠금',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
          ),
        ],
      ),
    );
  }
}
