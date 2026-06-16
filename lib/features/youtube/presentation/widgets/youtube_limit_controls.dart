import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/youtube/youtube_usage_lock.dart';
import '../../../../core/youtube/youtube_watch_timer_store.dart';

/// YouTube 한도 + 타임락 (설정·나의 Isle 공용)
class YoutubeLimitControls extends StatefulWidget {
  const YoutubeLimitControls({
    super.key,
    this.compact = false,
    this.hideUsageInCard = false,
  });

  final bool compact;
  /// 설정 화면 등 상단에 사용량을 이미 보여줄 때 카드 안 중복 숨김
  final bool hideUsageInCard;

  @override
  State<YoutubeLimitControls> createState() => _YoutubeLimitControlsState();
}

class _YoutubeLimitControlsState extends State<YoutubeLimitControls> {
  Timer? _wake;
  late bool _raiseLock;
  late int _freezeMinutes;
  Duration? _unlockLeft;

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
    YoutubeUsageLock.finalizeExpiredUnlock();
    _raiseLock = YoutubeUsageLock.raiseLockEnabled;
    _freezeMinutes = YoutubeUsageLock.unlockFreezeMinutes;
    _unlockLeft = YoutubeUsageLock.unlockRemaining;
  }

  void _scheduleWake() {
    _wake?.cancel();
    final left = _unlockLeft;
    if (left == null) return;
    final sec = left.inSeconds.clamp(1, 60);
    _wake = Timer(Duration(seconds: sec), () {
      if (!mounted) return;
      setState(_sync);
      _scheduleWake();
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h시간 ${m.toString().padLeft(2, '0')}분';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<bool> _confirmStartUnlock() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('한도 해제 대기를 시작할까요?'),
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

  Future<void> _startUnlock() async {
    if (!await _confirmStartUnlock()) return;
    await YoutubeUsageLock.startUnlockCountdown();
    if (!mounted) return;
    setState(_sync);
    _scheduleWake();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_freezeMinutes분 후 한도를 늘리거나 끌 수 있어요'),
      ),
    );
  }

  Future<void> _cancelUnlock({required String reason}) async {
    await YoutubeUsageLock.clearUnlockCountdown();
    if (!mounted) return;
    setState(_sync);
    _scheduleWake();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(reason)),
    );
  }

  Future<void> _confirmCancelUnlock() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대기를 취소할까요?'),
        content: const Text(
          '한도 해제 대기를 중단하고 타임락을 다시 유지합니다.\n'
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
    if (ok == true) {
      await _cancelUnlock(reason: '대기를 취소했어요 — 타임락이 다시 켜졌어요');
    }
  }

  Future<void> _setRaiseLock(bool v) async {
    if (!v && _raiseLock && !YoutubeUsageLock.canDisableRaiseLock) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('타임락을 끄려면 먼저 아래에서 대기를 완료하세요'),
        ),
      );
      return;
    }
    if (!v && _raiseLock) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('타임락을 끌까요?'),
          content: const Text(
            '꺼두면 한도를 바로 늘리거나 끌 수 있어요.\n'
            '실수로 끈 경우 다시 켜면 됩니다.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('유지')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('타임락 끄기'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await YoutubeUsageLock.setRaiseLockEnabled(v);
    if (!mounted) return;
    setState(_sync);
    _scheduleWake();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _unlockLeft != null;
    final canRaise = YoutubeUsageLock.unlockWindowOpen;
    final blocked = YoutubeUsageLock.raiseBlocked;

    if (widget.compact) {
      return _buildCard(waiting: waiting, canRaise: canRaise, blocked: blocked);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          YoutubeWatchTimerStore.formatStatusLine(),
          style: IsleText.caption(color: IsleColors.muted),
        ),
        const SizedBox(height: 8),
        _buildCard(waiting: waiting, canRaise: canRaise, blocked: blocked),
      ],
    );
  }

  Widget _buildCard({
    required bool waiting,
    required bool canRaise,
    required bool blocked,
  }) {
    return Card(
      color: waiting
          ? const Color(0xFFFFF3E0)
          : canRaise
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFEAF4FF),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_clock,
                  color: _raiseLock ? IsleColors.ocean700 : IsleColors.muted,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '타임락',
                        style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '한도 늘리기·끄기 전에 기다리기',
                        style: IsleText.caption(color: IsleColors.muted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _raiseLock,
                  onChanged: (v) => unawaited(_setRaiseLock(v)),
                ),
              ],
            ),
            if (!widget.hideUsageInCard) ...[
              const SizedBox(height: 6),
              Text(
                YoutubeWatchTimerStore.formatStatusLine(),
                style: IsleText.caption(color: IsleColors.ocean700).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              _raiseLock
                  ? (waiting
                      ? '⏳ 해제까지 ${_formatDuration(_unlockLeft!)}'
                      : canRaise
                          ? '✓ 대기 완료 — 지금 한도를 늘리거나 끌 수 있어요'
                          : blocked
                              ? '한도를 늘리거나 끄려면 아래에서 대기를 시작하세요'
                              : '줄이기는 저장으로 바로 · 늘리기/끄기는 대기 후')
                  : '꺼짐 — 한도를 바로 바꿀 수 있어요',
              style: IsleText.caption(
                color: waiting ? Colors.orange.shade900 : IsleColors.muted,
              ),
            ),
            if (_raiseLock && waiting) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: IsleSize.minTouchTarget,
                child: OutlinedButton.icon(
                  onPressed: _confirmCancelUnlock,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('대기 취소 · 잠금 유지'),
                ),
              ),
            ],
            if (_raiseLock && !waiting && !canRaise) ...[
              const SizedBox(height: 8),
              Text('대기 시간', style: IsleText.caption(color: IsleColors.muted)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [15, 30, 60, 120].map((m) {
                  return ChoiceChip(
                    label: Text('$m분'),
                    selected: _freezeMinutes == m,
                    onSelected: (_) async {
                      await YoutubeUsageLock.setUnlockFreezeMinutes(m);
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
                  onPressed: _startUnlock,
                  icon: const Icon(Icons.lock_clock_outlined),
                  label: Text('$_freezeMinutes분 대기 시작'),
                ),
              ),
            ],
            if (canRaise) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: IsleSize.minTouchTarget,
                child: FilledButton.tonalIcon(
                  onPressed: () => _cancelUnlock(
                    reason: '잠금을 유지했어요 — 한도는 변경되지 않았어요',
                  ),
                  icon: const Icon(Icons.lock),
                  label: const Text('잠금 유지 (한도 변경 안 함)'),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '실수로 대기를 시작했다면 위 버튼으로 다시 잠글 수 있어요',
                style: IsleText.caption(color: IsleColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
