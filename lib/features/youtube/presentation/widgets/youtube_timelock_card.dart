import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/block_schedule/block_schedule_store.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/platform/platform_block_intent.dart';
import '../../../../core/youtube/youtube_timelock_service.dart';
import 'screen_time_guide_sheet.dart';

/// 타임락 — 앱 내 유튜브 + Safari·YouTube 앱 차단 안내
class YoutubeTimelockCard extends ConsumerStatefulWidget {
  const YoutubeTimelockCard({super.key});

  @override
  ConsumerState<YoutubeTimelockCard> createState() => _YoutubeTimelockCardState();
}

class _YoutubeTimelockCardState extends ConsumerState<YoutubeTimelockCard> {
  var _busy = false;
  Timer? _wake;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPending());
  }

  @override
  void dispose() {
    _wake?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h시간 ${m.toString().padLeft(2, '0')}분';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _scheduleWake() {
    _wake?.cancel();
    final left = YoutubeTimelockService.disableRemaining;
    if (left == null) return;
    final sec = left.inSeconds.clamp(1, 30).toInt();
    _wake = Timer(Duration(seconds: sec), () {
      if (!mounted) return;
      unawaited(_refreshPending());
    });
  }

  Future<void> _refreshPending() async {
    await YoutubeTimelockService.processPendingDisable();
    if (!mounted) return;
    setState(() {});
    _scheduleWake();
  }

  Future<bool> _confirmDisable(int minutes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('타임락 끄기 대기를 시작할까요?'),
        content: Text(
          '지금부터 $minutes분 동안 카운트다운이 진행되고, 끝나면 YouTube 전체 차단이 자동으로 꺼져요.\n\n'
          '중간에 언제든 「해제 취소」로 타임락을 유지할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('유지'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('$minutes분 후 끄기'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<bool> _confirmLongerCooldown(int current, int next) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('타임락을 $next분으로 늘릴까요?'),
        content: Text(
          '현재 $current분 → $next분\n\n'
          '더 길게 만들면 이후 타임락을 끄거나 약하게 바꿀 때 더 오래 기다려야 해요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('$next분으로 적용'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    try {
      if (on) {
        await YoutubeTimelockService.enable();
        if (mounted && (Platform.isIOS || Platform.isAndroid)) {
          await showScreenTimeGuideSheet(context);
        }
      } else {
        final minutes = YoutubeTimelockService.schedule?.lockCooldownMinutes ??
            YoutubeTimelockService.defaultCooldownMinutes;
        if (!await _confirmDisable(minutes)) return;
        final result = await YoutubeTimelockService.requestDisable();
        if (mounted && result.kind == YoutubeTimelockDisableRequestKind.pending) {
          final left = result.remaining ?? Duration(minutes: minutes);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_formatDuration(left)} 후 타임락이 자동으로 꺼져요')),
          );
        }
      }
      await BlockScheduleStore.ensureOpen();
      if (mounted) setState(() {});
      _scheduleWake();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelDisable() async {
    await YoutubeTimelockService.cancelDisableRequest();
    if (!mounted) return;
    setState(() {});
    _scheduleWake();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('타임락 해제 대기를 취소했어요')),
    );
  }

  Future<void> _setCooldown(int minutes) async {
    final current = YoutubeTimelockService.schedule?.lockCooldownMinutes ??
        YoutubeTimelockService.defaultCooldownMinutes;
    if (minutes == current) return;

    if (minutes > current && !await _confirmLongerCooldown(current, minutes)) {
      return;
    }
    if (minutes < current && !YoutubeTimelockService.canSetCooldownMinutes(minutes)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$current분보다 줄이려면 먼저 타임락 해제 대기를 완료하세요'),
        ),
      );
      return;
    }

    final ok = await YoutubeTimelockService.setCooldownMinutes(minutes);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지금은 타임락 시간을 줄일 수 없어요')),
      );
      return;
    }
    setState(() {});
    _scheduleWake();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('타임락 대기 시간을 $minutes분으로 적용했어요')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final on = YoutubeTimelockService.isActive;
    final pending = YoutubeTimelockService.disablePending;
    final remaining = YoutubeTimelockService.disableRemaining;
    final cooldown = YoutubeTimelockService.schedule?.lockCooldownMinutes ??
        YoutubeTimelockService.defaultCooldownMinutes;

    return Card(
      color: pending
          ? const Color(0xFFFFF3E0)
          : on
              ? Colors.red.shade50
              : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phonelink_lock, color: on ? Colors.red.shade700 : IsleColors.ocean700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('YouTube 전체 차단 (타임락)', style: IsleText.subtitle()),
                ),
                if (_busy)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(value: on, onChanged: _toggle),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              pending && remaining != null
                  ? '해제 대기 중 · ${_formatDuration(remaining)} 후 자동으로 꺼져요'
                  : on
                      ? 'Isle WebView 유튜브가 잠겼어요. 끄기는 $cooldown분 대기 후 자동 적용돼요. ${PlatformBlockCopy.focusPanelExternalHint}'
                      : '켜면 24시간 스케줄 잠금이 적용되고, 외부 브라우저 차단 가이드가 열려요.',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            if (on) ...[
              const SizedBox(height: 10),
              Text('끄기 대기 시간', style: IsleText.caption(color: IsleColors.muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: YoutubeTimelockService.cooldownChoices.map((m) {
                  return ChoiceChip(
                    label: Text('$m분'),
                    selected: cooldown == m,
                    onSelected: _busy ? null : (_) => unawaited(_setCooldown(m)),
                  );
                }).toList(),
              ),
            ],
            if (pending) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _cancelDisable,
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('해제 취소 · 타임락 유지'),
                ),
              ),
            ],
            if ((Platform.isIOS || Platform.isAndroid) && on) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showScreenTimeGuideSheet(context),
                icon: const Icon(Icons.settings_suggest_outlined, size: 18),
                label: Text('${PlatformBlockCopy.externalBrowserName} · YouTube 앱 차단'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
