import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/block/rule_pending_removal_service.dart';
import '../../core/block/rule_removal_lock.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';

/// 키워드·URL·앱 **제거** 전 타임락 UI (추가는 항상 즉시)
class RuleRemovalLockControls extends StatefulWidget {
  const RuleRemovalLockControls({
    super.key,
    this.compact = false,
    /// 키워드·URL — 항목별 N분 후 자동 삭제 (전역 타이머 없음)
    this.perItemDelay = false,
  });

  final bool compact;
  final bool perItemDelay;

  @override
  State<RuleRemovalLockControls> createState() => _RuleRemovalLockControlsState();
}

class _RuleRemovalLockControlsState extends State<RuleRemovalLockControls> {
  Timer? _wake;
  late bool _lockOn;
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
    RuleRemovalLock.finalizeExpiredUnlock();
    _lockOn = RuleRemovalLock.lockEnabled;
    _freezeMinutes = RuleRemovalLock.freezeMinutes;
    _unlockLeft = RuleRemovalLock.unlockRemaining;
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
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<bool> _confirmIncreaseFreeze(int newMinutes) async {
    if (newMinutes <= _freezeMinutes) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('대기 시간을 $newMinutes분으로 늘릴까요?'),
        content: Text(
          '현재 $_freezeMinutes분 → $newMinutes분\n\n'
          '늘리면 나중에 키워드·URL·앱을 지울 때 더 오래 기다려야 해요.\n'
          '「타이머 시작」은 아직 누르지 않았어요 — 시간만 바뀝니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('$newMinutes분으로 변경'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<bool> _confirmStartUnlock() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 타이머를 시작할까요?'),
        content: Text(
          '지금부터 $_freezeMinutes분 동안 카운트다운이 진행돼요.\n\n'
          '• 이 화면을 닫아도 · 다른 앱을 써도 시간은 계속 흘러요\n'
          '• $_freezeMinutes분이 지나면 잠시 동안 목록에서 지울 수 있어요\n'
          '• 키워드·URL 추가는 지금도 바로 가능해요\n'
          '• 타이머 도중 「대기 취소」로 언제든 중단할 수 있어요',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('$_freezeMinutes분 타이머 시작'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _startUnlock() async {
    if (!await _confirmStartUnlock()) return;
    await RuleRemovalLock.startUnlockCountdown();
    if (!mounted) return;
    setState(_sync);
    _scheduleWake();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$_freezeMinutes분 타이머 시작 — 이 화면을 닫아도 괜찮아요',
        ),
      ),
    );
  }

  Future<void> _cancelUnlock({required String reason}) async {
    await RuleRemovalLock.clearUnlockCountdown();
    if (!mounted) return;
    setState(_sync);
    _scheduleWake();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
  }

  Future<void> _confirmCancelUnlock() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('타이머를 취소할까요?'),
        content: const Text(
          '카운트다운을 중단하고 삭제 대기를 다시 유지합니다.\n'
          '목록은 그대로입니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속 기다리기')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('타이머 취소 · 잠금 유지'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _cancelUnlock(reason: '타이머를 취소했어요 — 아직 지울 수 없어요');
    }
  }

  Future<void> _setLockOn(bool v) async {
    if (!widget.perItemDelay &&
        !v &&
        _lockOn &&
        !RuleRemovalLock.canDisableLock) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('타임락을 끄려면 먼저 아래에서 타이머를 완료하세요')),
      );
      return;
    }
    if (!v && _lockOn) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('제거 타임락을 끌까요?'),
          content: const Text(
            '꺼두면 키워드·URL·앱을 바로 지울 수 있어요.\n'
            '다시 켜면 삭제 전 대기가 적용됩니다.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('유지')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('타임락 끄기')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await RuleRemovalLock.setLockEnabled(v);
    if (!mounted) return;
    setState(_sync);
    _scheduleWake();
  }

  Future<void> _pickFreezeMinutes(int m) async {
    if (m == _freezeMinutes) return;
    if (!widget.perItemDelay && !RuleRemovalLock.canSetFreezeMinutes(m)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '대기 시간을 $_freezeMinutes분보다 줄이려면 먼저 타이머를 완료하세요',
          ),
        ),
      );
      return;
    }
    if (m > _freezeMinutes && !await _confirmIncreaseFreeze(m)) return;
    final applied = m;
    await RuleRemovalLock.setFreezeMinutes(applied);
    if (!mounted) return;
    setState(() => _freezeMinutes = applied);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.perItemDelay
              ? '삭제 대기: $applied분 — X를 누르면 $applied분 후 자동 제거'
              : '삭제 대기 시간: $applied분 (타이머는 아직 시작 안 됨)',
        ),
      ),
    );
  }

  Widget _infoLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: IsleColors.ocean700),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: IsleText.caption(color: IsleColors.muted))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.perItemDelay) return _buildPerItemDelayCard(context);

    final waiting = _unlockLeft != null;
    final canRemove = RuleRemovalLock.unlockWindowOpen;
    final blocked = RuleRemovalLock.removalBlocked;

    return Card(
      margin: widget.compact ? EdgeInsets.zero : null,
      color: waiting
          ? const Color(0xFFFFF3E0)
          : canRemove
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFEAF4FF),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_clock,
                  color: _lockOn ? IsleColors.ocean700 : IsleColors.muted,
                  size: widget.compact ? 20 : 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '제거 대기 시간',
                        style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '실수로 규칙을 지우지 않게 대기 시간을 둡니다',
                        style: IsleText.caption(color: IsleColors.muted),
                      ),
                    ],
                  ),
                ),
                Switch(value: _lockOn, onChanged: (v) => unawaited(_setLockOn(v))),
              ],
            ),
            Text(
              _lockOn
                  ? (waiting
                      ? '⏳ 삭제 가능까지 ${_formatDuration(_unlockLeft!)} — 화면을 닫아도 계속'
                      : canRemove
                          ? '✓ 타이머 완료 — 지금 키워드·URL·앱을 지울 수 있어요'
                          : blocked
                              ? '지우려면 아래에서 타이머를 시작하세요'
                              : '추가는 바로 · 삭제는 타이머 후')
                  : '꺼짐 — 목록에서 바로 지울 수 있어요',
              style: IsleText.caption(
                color: waiting ? Colors.orange.shade900 : IsleColors.muted,
              ),
            ),
            if (_lockOn && waiting) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: IsleSize.minTouchTarget,
                child: OutlinedButton.icon(
                  onPressed: _confirmCancelUnlock,
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('타이머 취소 · 잠금 유지'),
                ),
              ),
            ],
            if (_lockOn && !waiting && !canRemove) ...[
              const SizedBox(height: 8),
              Text(
                '삭제 대기 시간 (탭하면 확인 · 타이머는 별도 버튼)',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [5, 15, 30, 60, 120].map((m) {
                  return ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text('$m분'),
                    selected: _freezeMinutes == m,
                    onSelected: (_) => unawaited(_pickFreezeMinutes(m)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '타이머를 시작하면',
                      style: IsleText.caption().copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    _infoLine(Icons.timer_outlined, '$_freezeMinutes분 카운트다운이 백그라운드에서 진행돼요'),
                    _infoLine(Icons.exit_to_app, '이 화면을 닫거나 다른 앱을 써도 시간은 계속 흘러요'),
                    _infoLine(Icons.delete_outline, '끝나면 잠시 동안 목록에서 지울 수 있어요'),
                    _infoLine(Icons.add_circle_outline, '키워드 추가는 지금도 바로 가능해요'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: IsleSize.minTouchTarget,
                child: FilledButton.icon(
                  onPressed: _startUnlock,
                  icon: const Icon(Icons.timer_outlined),
                  label: Text('$_freezeMinutes분 삭제 타이머 시작'),
                ),
              ),
            ],
            if (canRemove) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: IsleSize.minTouchTarget,
                child: FilledButton.tonalIcon(
                  onPressed: () => _cancelUnlock(reason: '잠금을 유지했어요 — 목록은 변경되지 않았어요'),
                  icon: const Icon(Icons.lock),
                  label: const Text('잠금 유지 (삭제 안 함)'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPerItemDelayCard(BuildContext context) {
    return Card(
      margin: widget.compact ? EdgeInsets.zero : null,
      color: _lockOn ? const Color(0xFFEAF4FF) : null,
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_clock,
                  color: _lockOn ? IsleColors.ocean700 : IsleColors.muted,
                  size: widget.compact ? 20 : 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '삭제 타임락',
                        style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '추가는 즉시 · X는 대기 후 자동 삭제',
                        style: IsleText.caption(color: IsleColors.muted),
                      ),
                    ],
                  ),
                ),
                Switch(value: _lockOn, onChanged: (v) => unawaited(_setLockOn(v))),
              ],
            ),
            Text(
              _lockOn
                  ? '목록에서 X를 누르면 $_freezeMinutes분 후 자동 제거 · 그동안 차단 유지'
                  : '꺼짐 — X를 누르면 바로 삭제',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            if (_lockOn) ...[
              const SizedBox(height: 8),
              Text(
                '삭제 대기 시간',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [5, 15, 30, 35, 60, 120].map((m) {
                  return ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text('$m분'),
                    selected: _freezeMinutes == m,
                    onSelected: (_) => unawaited(_pickFreezeMinutes(m)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 제거가 막혀 있을 때 스낵바
void showRuleRemovalBlockedSnackBar(BuildContext context) {
  final min = RuleRemovalLock.freezeMinutes;
  final waiting = RuleRemovalLock.unlockRemaining;
  final message = waiting != null
      ? '삭제 타이머 진행 중 — ${_fmtLeft(waiting)} 남았어요'
      : '제거 타임락 — 「$min분 삭제 타이머 시작」 후에 지울 수 있어요 (추가는 지금 가능)';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _fmtLeft(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60);
  return m > 0 ? '$m분 $s초' : '$s초';
}

/// 키워드·URL 항목별 지연 삭제 결과 스낵바
void showRuleRemovalOutcomeSnackBar(
  BuildContext context,
  RuleRemovalOutcome outcome, {
  required int freezeMinutes,
  required String itemLabel,
}) {
  final String message;
  switch (outcome.kind) {
    case RuleRemovalOutcomeKind.immediate:
      message = '$itemLabel 삭제했어요';
    case RuleRemovalOutcomeKind.scheduled:
      final min = outcome.remaining?.inMinutes ?? freezeMinutes;
      message = itemLabel.contains('팩')
          ? '$min분 후 자동으로 연결 해제됩니다 · 그동안 차단은 유지'
          : '$min분 후 자동으로 제거됩니다 · 그동안 차단은 유지';
    case RuleRemovalOutcomeKind.alreadyPending:
      message =
          '이미 삭제 예약됨 — ${RulePendingRemovalService.formatRemaining(outcome.remaining!)}';
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
