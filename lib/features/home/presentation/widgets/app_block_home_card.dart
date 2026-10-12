import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/block_schedule/app_block_config_service.dart';
import '../../../../core/block_schedule/app_block_pause_service.dart';
import '../../../../core/block_schedule/models/block_schedule.dart';
import '../../../../core/block_schedule/models/schedule_enforcement_mode.dart';
import '../../../../core/block_schedule/schedule_active_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/quick_block_context_copy.dart';
import '../../../../core/intervention/schedule_screen_time_store.dart';

/// 홈 화면 앱별 차단 카드용 표시 정보 — 앱마다 자기 이름으로 불려야 한다는
/// 요청(2026-07-20)에 따라 "Safari"라는 이름이 다른 앱에 새지 않도록 카드
/// 하나당 완전히 독립된 정적 정보만 갖는다(예전 QuickOsBlockPreset과 값은
/// 같지만, 그 서비스 로직에는 더 이상 의존하지 않음).
class AppBlockHomeCardInfo {
  const AppBlockHomeCardInfo({
    required this.bundleId,
    required this.title,
    required this.pickHint,
    required this.emoji,
    required this.accent,
    required this.whyTitle,
    required this.whyBody,
  });

  final String bundleId;
  final String title;
  final String pickHint;
  final String emoji;
  final int accent;
  final String whyTitle;
  final String whyBody;

  static const youtube = AppBlockHomeCardInfo(
    bundleId: 'youtube',
    title: '유튜브 앱',
    pickHint: 'YouTube',
    emoji: '🎬',
    accent: 0xFFFF0000,
    whyTitle: QuickBlockContextCopy.youtubeWhyTitle,
    whyBody: QuickBlockContextCopy.youtubeWhyBody,
  );

  static const safari = AppBlockHomeCardInfo(
    bundleId: 'safari',
    title: 'Safari',
    pickHint: 'Safari',
    emoji: '🧭',
    accent: 0xFF007AFF,
    whyTitle: QuickBlockContextCopy.safariWhyTitle,
    whyBody: QuickBlockContextCopy.safariWhyBody,
  );

  static const kakao = AppBlockHomeCardInfo(
    bundleId: 'kakao_talk',
    title: '카카오톡',
    pickHint: '카카오톡',
    emoji: '💬',
    accent: 0xFFFEE500,
    whyTitle: QuickBlockContextCopy.kakaoWhyTitle,
    whyBody: QuickBlockContextCopy.kakaoWhyBody,
  );

  static const youtubeMusic = AppBlockHomeCardInfo(
    bundleId: 'youtube_music',
    title: 'YouTube Music',
    pickHint: 'YouTube Music',
    emoji: '🎵',
    accent: 0xFFFF0000,
    whyTitle: QuickBlockContextCopy.youtubeMusicWhyTitle,
    whyBody: QuickBlockContextCopy.youtubeMusicWhyBody,
  );
}

/// 차단 홈 — 앱별 개별 카드 (2026-07-20 재구성).
///
/// 예전 `QuickOsBlockCard`는 4개 앱이 전부 하나의 공유 Screen Time 선택값을
/// 나눠 썼다(새 앱을 고르면 기존 선택에 병합돼 "싸잡아짐" — 실사용 제보).
/// 이 카드는 [AppBlockConfigService]가 앱마다 따로 관리하는 스케줄 하나만
/// 보고 토글하므로, 앱마다 독립적으로 차단된다. 스위치는 "이미 정해둔
/// 시간대·방식이 지금 켜져 있는지"만 반영하고(무작정 활성화 아님), 처음
/// 켤 때만 24시간 항상 차단을 기본값으로 만든다.
class AppBlockHomeCard extends StatefulWidget {
  const AppBlockHomeCard({
    super.key,
    required this.info,
    this.onChanged,
    this.onTap,
  });

  final AppBlockHomeCardInfo info;
  final VoidCallback? onChanged;

  /// 카드 본문(스위치 제외) 탭 — [AppBlockDetailScreen]으로 이동해 시간대·
  /// 나눠쓰기 방식을 직접 설정.
  final VoidCallback? onTap;

  @override
  State<AppBlockHomeCard> createState() => _AppBlockHomeCardState();
}

class _AppBlockHomeCardState extends State<AppBlockHomeCard> {
  BlockSchedule? _schedule;
  bool _hasSelection = false;
  bool _loaded = false;
  bool _busy = false;

  String get _bundleId => widget.info.bundleId;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    await AppBlockPauseService.checkAndRestoreIfExpired(_bundleId);
    final schedule = await AppBlockConfigService.existingFor(_bundleId);
    final hasSelection = schedule == null
        ? false
        : ScheduleScreenTimeStore.hasAnySelection(schedule.id);
    if (!mounted) return;
    setState(() {
      _schedule = schedule;
      _hasSelection = hasSelection;
      _loaded = true;
    });
  }

  bool get _is24h {
    final s = _schedule;
    if (s == null || s.slots.length < 7) return false;
    return s.slots.every((sl) => sl.startMinute == 0 && sl.endMinute == 1439);
  }

  bool get _paused => AppBlockPauseService.isPaused(_bundleId);

  bool get _switchOn => _schedule?.enabled ?? false;

  bool get _blockedNow {
    final s = _schedule;
    if (s == null || _paused) return false;
    return ScheduleActiveService.isScheduleActiveNow(s);
  }

  String get _statusLabel {
    final s = _schedule;
    if (s == null || !s.enabled) return '🔓 안 막음';
    if (_paused) {
      final left = AppBlockPauseService.remainingSeconds(_bundleId);
      final min = (left / 60).ceil().clamp(1, 999);
      return '⏸️ 잠깐 허용 중 (약 $min분 뒤 다시 잠김)';
    }
    if (!_hasSelection) return '⚠️ 앱 선택이 필요해요';
    if (_is24h) return '🔒 24시간 계속 막는 중';
    if (s.enforcementMode == ScheduleEnforcementMode.limitInSlot) {
      return _blockedNow ? '🔒 나눠 쓰기 적용 중' : '나눠 쓰기 설정됨 · 지금은 시간대 아님';
    }
    return _blockedNow ? '🔒 지금 막는 중' : '설정됨 · 지금은 시간대 아님';
  }

  Future<void> _onToggle(bool wantOn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!wantOn && _paused) {
        await AppBlockPauseService.cancelPause(_bundleId);
      }
      await AppBlockConfigService.setEnabled(_bundleId, wantOn);
      await _reload();
      widget.onChanged?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pause(int minutes) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AppBlockPauseService.pauseFor(_bundleId, minutes);
      await _reload();
      widget.onChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.info.title} $minutes분 허용했어요')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final accent = Color(info.accent);
    final blocked = _blockedNow;
    final needsSelection = (_schedule?.enabled ?? false) && !_hasSelection;
    final paused = _paused;
    final bg = blocked
        ? accent.withValues(alpha: 0.14)
        : needsSelection
            ? const Color(0xFFFFEBEE)
            : paused
                ? const Color(0xFFFFF8E1)
                : Colors.white;
    final border = blocked
        ? accent.withValues(alpha: 0.55)
        : needsSelection
            ? IsleColors.danger.withValues(alpha: 0.45)
            : paused
                ? const Color(0xFFFFCC80)
                : IsleColors.ocean100;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: blocked || paused ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child:
                        Text(info.emoji, style: const TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.title,
                          style: IsleText.subtitle(color: IsleColors.ocean900)
                              .copyWith(
                                  fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _loaded ? _statusLabel : '…',
                          style: IsleText.body(
                            color: blocked || paused || needsSelection
                                ? accent
                                : IsleColors.muted,
                          ).copyWith(
                            fontWeight: blocked || paused || needsSelection
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_busy || !_loaded)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else
                    Transform.scale(
                      scale: 1.25,
                      child: Switch(
                        value: _switchOn,
                        onChanged: _onToggle,
                        activeThumbColor: Colors.white,
                        activeTrackColor: accent,
                      ),
                    ),
                ],
              ),
              if (needsSelection) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : widget.onTap,
                    icon: const Icon(Icons.tune, size: 20),
                    label: const Text('세부 설정으로 이동'),
                  ),
                ),
              ],
              if (_switchOn) ...[
                const SizedBox(height: 12),
                _PauseChips(
                  paused: paused,
                  busy: _busy,
                  onPause: _pause,
                  onCancel: () async {
                    if (_busy) return;
                    setState(() => _busy = true);
                    try {
                      await AppBlockPauseService.cancelPause(_bundleId);
                      await _reload();
                      widget.onChanged?.call();
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
                ),
              ],
              const SizedBox(height: 4),
              _WhyRow(title: info.whyTitle, body: info.whyBody),
            ],
          ),
        ),
      ),
    );
  }
}

class _PauseChips extends StatelessWidget {
  const _PauseChips({
    required this.paused,
    required this.busy,
    required this.onPause,
    required this.onCancel,
  });

  final bool paused;
  final bool busy;
  final void Function(int minutes) onPause;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (paused) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: busy ? null : onCancel,
          child: const Text('지금 다시 잠그기'),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [5, 10, 15].map((m) {
        return OutlinedButton(
          onPressed: busy ? null : () => onPause(m),
          child: Text('$m분 허용'),
        );
      }).toList(),
    );
  }
}

class _WhyRow extends StatefulWidget {
  const _WhyRow({required this.title, required this.body});

  final String title;
  final String body;

  @override
  State<_WhyRow> createState() => _WhyRowState();
}

class _WhyRowState extends State<_WhyRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.help_outline,
                  size: 18,
                  color: IsleColors.ocean700,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.title,
                  style: IsleText.caption(color: IsleColors.ocean700)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              widget.body,
              style: IsleText.caption(color: IsleColors.muted)
                  .copyWith(height: 1.45),
            ),
          ),
      ],
    );
  }
}
