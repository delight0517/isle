import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/library/platform_watch_limit_store.dart';
import '../../../../core/social/instagram_usage_lock.dart';

/// Instagram 피드/DM — 일일 한도 + 설정 변경 타임락 (이용 중 시트·설정 화면 공용)
class InstagramLimitControls extends StatefulWidget {
  const InstagramLimitControls({
    super.key,
    required this.scope,
    this.compact = false,
  });

  final InstagramUsageScope scope;
  final bool compact;

  @override
  State<InstagramLimitControls> createState() => _InstagramLimitControlsState();
}

class _InstagramLimitControlsState extends State<InstagramLimitControls> {
  Timer? _wake;
  late bool _enabled;
  late double _minutes;
  late int _freezeMinutes;
  Duration? _freezeLeft;

  PlatformWatchId get _watchId => widget.scope == InstagramUsageScope.feed
      ? PlatformWatchId.instagram
      : PlatformWatchId.instagramDm;

  @override
  void initState() {
    super.initState();
    _sync();
    _scheduleWake();
  }

  @override
  void dispose() {
    _wake?.cancel();
    super.dispose();
  }

  void _sync() {
    widget.scope.finalizeExpiredFreeze();
    _enabled = PlatformWatchLimitStore.isEnabled(_watchId);
    _minutes = PlatformWatchLimitStore.limitMinutes(_watchId).toDouble();
    _freezeMinutes = widget.scope.freezeMinutes;
    _freezeLeft = widget.scope.unlockRemaining;
  }

  void _scheduleWake() {
    _wake?.cancel();
    final left = _freezeLeft;
    if (left == null) return;
    final sec = left.inSeconds.clamp(1, 60);
    _wake = Timer(Duration(seconds: sec), () {
      if (!mounted) return;
      setState(_sync);
      _scheduleWake();
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get _canEditLimit => !widget.scope.isSettingsFrozen;

  Future<bool> _confirmStartFreeze() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${widget.scope.shortLabel} 설정 변경 대기를 시작할까요?'),
        content: Text(
          '$_freezeMinutes분 동안 기다린 뒤에만 한도를 늘리거나 끌 수 있어요.\n'
          '시작 후에도 「대기 취소」로 잠금을 유지할 수 있어요.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('$_freezeMinutes분 대기 시작'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _startFreeze() async {
    if (!await _confirmStartFreeze()) return;
    await widget.scope.startFreezeCountdown();
    if (!mounted) return;
    setState(_sync);
    _scheduleWake();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.scope.shortLabel} 한도·설정 변경은 $_freezeMinutes분 후에 가능해요',
        ),
      ),
    );
  }

  Future<void> _cancelFreeze() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대기를 취소할까요?'),
        content: const Text(
          '설정 변경 대기를 중단하고 타임락을 다시 유지합니다.\n'
          '한도는 지금 그대로입니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속 대기')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('대기 취소 · 잠금 유지'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.scope.clearFreezeCountdown();
    if (!mounted) return;
    setState(_sync);
    _scheduleWake();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('대기를 취소했어요 — 타임락이 다시 켜졌어요')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final used = PlatformWatchLimitStore.secondsUsedToday(_watchId);
    final limit = PlatformWatchLimitStore.limitSeconds(_watchId);
    final frozen = _freezeLeft != null;

    if (widget.compact) {
      return _freezeSection(frozen);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '오늘 ${used ~/ 60}분 / ${limit ~/ 60}분 · '
          '${PlatformWatchLimitStore.formatRemainChip(_watchId)}',
          style: IsleText.caption(color: IsleColors.muted),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('일일 한도'),
          value: _enabled,
          onChanged: _canEditLimit
              ? (v) async {
                  await PlatformWatchLimitStore.setEnabled(_watchId, v);
                  setState(() => _enabled = v);
                }
              : null,
        ),
        Slider(
          min: 5,
          max: 180,
          divisions: 35,
          label: '${_minutes.round()}분',
          value: _minutes,
          onChanged: _enabled && _canEditLimit
              ? (v) async {
                  setState(() => _minutes = v);
                  await PlatformWatchLimitStore.setLimitMinutes(_watchId, v.round());
                }
              : null,
        ),
        const SizedBox(height: 8),
        _freezeSection(frozen),
      ],
    );
  }

  Widget _freezeSection(bool frozen) {
    return Card(
      color: frozen ? const Color(0xFFFFF3E0) : const Color(0xFFEAF4FF),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('설정 타임락', style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              frozen
                  ? '해제 대기 ${_formatDuration(_freezeLeft!)}'
                  : '한도를 올리거나 끄기 전에 대기 시간을 둡니다',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            if (!frozen) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [15, 30, 45, 60].map((m) {
                  return ChoiceChip(
                    label: Text('$m분'),
                    selected: _freezeMinutes == m,
                    onSelected: (_) async {
                      await widget.scope.setFreezeMinutes(m);
                      if (!mounted) return;
                      setState(() => _freezeMinutes = m);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: IsleSize.minTouchTarget,
                child: FilledButton.icon(
                  onPressed: _startFreeze,
                  icon: const Icon(Icons.lock_clock_outlined),
                  label: Text('변경 전 $_freezeMinutes분 대기 시작'),
                ),
              ),
            ],
            if (frozen) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: IsleSize.minTouchTarget,
                child: OutlinedButton.icon(
                  onPressed: _cancelFreeze,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('대기 취소 · 잠금 유지'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
