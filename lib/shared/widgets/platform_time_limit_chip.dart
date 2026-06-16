import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/library/platform_watch_limit_store.dart';
import '../../core/navigation/isle_routes.dart';
import '../../core/navigation/isle_navigation.dart';
import '../../core/social/instagram_usage_lock.dart';
import '../../core/youtube/youtube_usage_lock.dart';
import '../../core/youtube/youtube_watch_timer_store.dart';
import '../../features/social/presentation/widgets/instagram_limit_controls.dart';
import 'isle_sheet.dart';

/// WebView 상단 — 플랫폼별 남은 시간 (YouTube는 조회만 · 변경은 설정)
class PlatformTimeLimitChip extends StatelessWidget {
  const PlatformTimeLimitChip({
    super.key,
    required this.platform,
    this.compact = false,
    this.fg = Colors.white,
    this.bg,
  });

  final PlatformWatchId platform;
  final bool compact;
  final Color fg;
  final Color? bg;

  bool get _isYoutube => platform == PlatformWatchId.youtube;

  @override
  Widget build(BuildContext context) {
    final enabled = PlatformWatchLimitStore.isEnabled(platform);
    final reached = PlatformWatchLimitStore.isLimitReached(platform);
    final label = PlatformWatchLimitStore.formatRemainChip(platform);
    final used = PlatformWatchLimitStore.secondsUsedToday(platform);
    final limit = PlatformWatchLimitStore.limitSeconds(platform);

    final chipBg = reached
        ? Colors.red.shade700.withValues(alpha: 0.92)
        : (bg ?? Colors.black.withValues(alpha: 0.55));

    return Material(
      color: chipBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openSheet(context),
        onLongPress: _isYoutube ? null : () => _openSettings(context),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isYoutube
                    ? Icons.lock_clock
                    : (enabled ? Icons.timer_outlined : Icons.timer_off_outlined),
                size: compact ? 16 : 18,
                color: fg,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: IsleText.caption(color: fg).copyWith(fontWeight: FontWeight.w600),
              ),
              if (!compact) ...[
                const SizedBox(width: 4),
                Text(
                  '· ${used ~/ 60}/${limit ~/ 60}분',
                  style: IsleText.caption(color: fg.withValues(alpha: 0.75)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showIsleModalSheet<void>(
      context: context,
      builder: (ctx) => _PlatformLimitSheet(platform: platform),
    );
  }

  void _openSettings(BuildContext context) {
    HapticFeedback.selectionClick();
    if (platform == PlatformWatchId.instagram) {
      IsleNavigation.push('/settings/instagram-limits?scope=feed', from: context);
    } else if (platform == PlatformWatchId.instagramDm) {
      IsleNavigation.push('/settings/instagram-limits?scope=dm', from: context);
    } else {
      IsleNavigation.push(IsleRoutes.blockSchedules, from: context);
    }
  }
}

class _PlatformLimitSheet extends StatefulWidget {
  const _PlatformLimitSheet({required this.platform});

  final PlatformWatchId platform;

  @override
  State<_PlatformLimitSheet> createState() => _PlatformLimitSheetState();
}

class _PlatformLimitSheetState extends State<_PlatformLimitSheet> {
  late bool _enabled;
  late double _minutes;

  @override
  void initState() {
    super.initState();
    _enabled = PlatformWatchLimitStore.isEnabled(widget.platform);
    _minutes = PlatformWatchLimitStore.limitMinutes(widget.platform).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.platform == PlatformWatchId.youtube) {
      return _YoutubeLimitStatusSheet(
        onOpenSettings: () {
          Navigator.pop(context);
          IsleNavigation.push(IsleRoutes.youtubeLimits, from: context);
        },
      );
    }

    final name = PlatformWatchLimitStore.label(widget.platform);
    final igScope = switch (widget.platform) {
      PlatformWatchId.instagram => InstagramUsageScope.feed,
      PlatformWatchId.instagramDm => InstagramUsageScope.dm,
      _ => null,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$name · 일일 한도', style: IsleText.subtitle()),
            const SizedBox(height: 12),
            if (igScope != null)
              InstagramLimitControls(scope: igScope)
            else ...[
              Text(
                '오늘 ${PlatformWatchLimitStore.secondsUsedToday(widget.platform) ~/ 60}분 / '
                '${PlatformWatchLimitStore.limitSeconds(widget.platform) ~/ 60}분',
                style: IsleText.caption(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('한도 사용'),
                value: _enabled,
                onChanged: (v) async {
                  await PlatformWatchLimitStore.setEnabled(widget.platform, v);
                  setState(() => _enabled = v);
                },
              ),
              Slider(
                min: 5,
                max: 180,
                divisions: 35,
                label: '${_minutes.round()}분',
                value: _minutes,
                onChanged: _enabled
                    ? (v) async {
                        setState(() => _minutes = v);
                        await PlatformWatchLimitStore.setLimitMinutes(
                          widget.platform,
                          v.round(),
                        );
                      }
                    : null,
              ),
            ],
            if (igScope != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  IsleNavigation.push(
                    '/settings/instagram-limits?scope=${igScope.name}',
                    from: context,
                  );
                },
                child: const Text('상세 설정'),
              ),
            SizedBox(
              height: IsleSize.minTouchTarget,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('완료'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 인앱 YouTube — 슬라이더 없음. 변경은 설정 + 타임락만.
class _YoutubeLimitStatusSheet extends StatelessWidget {
  const _YoutubeLimitStatusSheet({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final reached = PlatformWatchLimitStore.isLimitReached(PlatformWatchId.youtube);
    final used = PlatformWatchLimitStore.secondsUsedToday(PlatformWatchId.youtube);
    final limit = PlatformWatchLimitStore.limitSeconds(PlatformWatchId.youtube);
    final reset = YoutubeWatchTimerStore.timeUntilReset();
    final h = reset.inHours;
    final m = reset.inMinutes.remainder(60);
    final interval = YoutubeWatchTimerStore.usesInterval;
    final timelockOn = YoutubeUsageLock.raiseLockEnabled;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_clock, color: IsleColors.ocean700),
                const SizedBox(width: 8),
                Expanded(child: Text('유튜브 시청 한도', style: IsleText.subtitle())),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '오늘 ${used ~/ 60}분 / ${limit ~/ 60}분',
              style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (reached)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  interval
                      ? '이번 주기 한도 소진 — 다음 주기까지 $h시간 $m분\n여기서는 한도를 바꿀 수 없어요.'
                      : '오늘 한도 소진 — 자정까지 $h시간 $m분\n여기서는 한도를 바꿀 수 없어요.',
                  style: IsleText.caption(color: Colors.red.shade900),
                ),
              )
            else
              Text(
                '시청 중: 줄이기는 설정에서 저장으로 바로 적용돼요.\n'
                '늘리기·끄기는 타임락${timelockOn ? '' : ' 켠 뒤'} 대기 후에만 가능해요.',
                style: IsleText.caption(color: IsleColors.muted),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: IsleSize.minTouchTarget,
              child: FilledButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('설정에서 한도 · 타임락'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: IsleSize.minTouchTarget,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
