import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/focus/kakao_shorts_addiction_analyzer.dart';
import '../../../core/focus/kakao_shorts_addiction_store.dart';
import '../../../core/focus/kakao_shorts_preset_service.dart';
import '../../../core/focus/kakao_shorts_session.dart';
import '../../../core/platform/isle_apple_platform.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 검색 「포모도로」로 들어오는 — 귀엽고 단순한 과소비 끊기
class PomodoroBreakScreen extends StatefulWidget {
  const PomodoroBreakScreen({super.key, this.openRefill = false});

  final bool openRefill;

  @override
  State<PomodoroBreakScreen> createState() => _PomodoroBreakScreenState();
}

class _PomodoroBreakScreenState extends State<PomodoroBreakScreen> {
  bool _on = false;
  bool _watching = false;
  bool _busy = false;
  KakaoShortsInsight? _insight;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && (_on || _watching)) unawaited(_load(silent: true));
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    await KakaoShortsAddictionStore.ensureOpen();
    if (!mounted) return;
    if (!silent) setState(() => _busy = true);
    setState(() {
      _on = KakaoShortsAddictionStore.pomodoroEnabled;
      _watching = KakaoShortsAddictionStore.openSession() != null;
      _insight = KakaoShortsAddictionAnalyzer.analyze();
      _busy = false;
    });
  }

  Future<void> _toggleOn(bool v) async {
    HapticFeedback.lightImpact();
    await KakaoShortsAddictionStore.setPomodoroEnabled(v);
    await _load();
    if (!mounted) return;
    if (v) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🍅 30분 채우면 10분 휴식 — 휴식 때 카카오톡이 Screen Time으로 막혀요. '
            '「지금 보는 중」으로 시간을 재거나 5분 리필을 먼저 켜 주세요.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _toggleWatching() async {
    HapticFeedback.mediumImpact();
    if (_watching) {
      await KakaoShortsAddictionStore.endOpenSession();
    } else {
      await KakaoShortsAddictionStore.startManualSession();
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final workMin = KakaoShortsAddictionStore.workSecondsInCycle ~/ 60;
    const cap = KakaoShortsAddictionStore.defaultWorkMinutes;
    final onBreak = KakaoShortsAddictionStore.isOnBreak;
    final breakLeft = KakaoShortsAddictionStore.breakRemaining;
    final progress = (workMin / cap).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: const IsleAppBar(title: '포모도로 휴식'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 8, 24, IsleSize.scrollBottomPadding(context)),
        children: [
          Center(
            child: _TomatoRing(
              progress: onBreak ? 1.0 : progress,
              emoji: onBreak ? '🍵' : '🍅',
              label: onBreak
                  ? '쉬는 중'
                  : _on
                      ? '$workMin / $cap 분'
                      : '꺼짐',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            onBreak
                ? '잠깐 손 떼는 시간이에요'
                : '쇼츠·릴·짧은 영상 — 30분 보고 10분 쉬어요',
            style: IsleText.subtitle(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            Platform.isAndroid
                ? 'Android: 접근성 켜면 카카오톡 열 때 자동으로 세션이 잡혀요. '
                    '인스타·틱톡은 「지금 보는 중」버튼을 써 주세요.'
                : '카카오톡·인스타·틱톡 어디든 같은 규칙이에요. '
                    '앱을 완전히 막으려면 차단 탭의 「항상 막기」를 켜 주세요.',
            style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.45),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _on,
            onChanged: _busy ? null : _toggleOn,
            title: Text('포모도로 켜기', style: IsleText.body()),
            activeThumbColor: const Color(0xFFE53935),
          ),
          if (_on) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: IsleSize.minTouchTarget + 8,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _watching ? IsleColors.ocean700 : const Color(0xFFFF7043),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _busy ? null : _toggleWatching,
                child: Text(
                  _watching
                      ? (KakaoShortsAddictionStore.openSession()?.source ==
                              KakaoShortsSessionSource.androidUsage
                          ? '카카오톡 보는 중 (자동) · 종료'
                          : '그만 볼게요 · 종료')
                      : '지금 보는 중 🐣',
                  style: IsleText.body(color: Colors.white),
                ),
              ),
            ),
            if (onBreak && breakLeft != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${breakLeft.inMinutes}분 ${breakLeft.inSeconds.remainder(60)}초 뒤 다시 시작',
                  style: IsleText.caption(color: IsleColors.ocean700),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
          if (_insight != null && _on) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: IsleColors.ocean100),
              ),
              child: Text(
                _insight!.headline,
                style: IsleText.body(),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (widget.openRefill && IsleApplePlatform.isNativeBlockHost) ...[
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 8),
            Text('더 강하게 막기', style: IsleText.caption(color: IsleColors.muted)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final r = await KakaoShortsPresetService.applyMicroRefillSchedule();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            r.statusMessage(isIos: Platform.isIOS || Platform.isMacOS),
                          ),
                        ),
                      );
                    },
              child: const Text('5분 리필 스케줄 (고급)'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TomatoRing extends StatelessWidget {
  const _TomatoRing({
    required this.progress,
    required this.emoji,
    required this.label,
  });

  final double progress;
  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(160, 160),
            painter: _RingPainter(progress: progress),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 4),
              Text(label, style: IsleText.caption(color: IsleColors.ocean900)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;
    final bg = Paint()
      ..color = const Color(0xFFFFE0D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, bg);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
