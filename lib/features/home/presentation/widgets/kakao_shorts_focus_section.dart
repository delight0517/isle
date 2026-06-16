import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/focus/kakao_shorts_addiction_analyzer.dart';
import '../../../../core/focus/kakao_shorts_addiction_store.dart';
import '../../../../core/focus/kakao_shorts_preset_service.dart';
import '../../../../core/navigation/isle_routes.dart';
import '../../../../core/platform/isle_apple_platform.dart';

/// 카카오톡 쇼츠 — OS 차단 · 5분 리필 · 30·10 · 중독 인사이트
class KakaoShortsFocusSection extends StatefulWidget {
  const KakaoShortsFocusSection({super.key});

  @override
  State<KakaoShortsFocusSection> createState() => _KakaoShortsFocusSectionState();
}

class _KakaoShortsFocusSectionState extends State<KakaoShortsFocusSection> {
  KakaoShortsInsight? _insight;
  bool _pomodoro = false;
  bool _sessionOpen = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await KakaoShortsAddictionStore.ensureOpen();
    if (!mounted) return;
    setState(() {
      _insight = KakaoShortsAddictionAnalyzer.analyze();
      _pomodoro = KakaoShortsAddictionStore.pomodoroEnabled;
      _sessionOpen = KakaoShortsAddictionStore.openSession() != null;
    });
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _riskColor(KakaoShortsRiskLevel r) => switch (r) {
        KakaoShortsRiskLevel.low => IsleColors.ocean500,
        KakaoShortsRiskLevel.medium => IsleColors.gold500,
        KakaoShortsRiskLevel.high => IsleColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final insight = _insight;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: IsleColors.ocean700, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text('카카오톡 쇼츠', style: IsleText.subtitle())),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              Platform.isAndroid
                  ? '쇼츠는 카카오톡 앱 안에서만 돌아가요. '
                      '① 접근성 앱 차단 ② 5분마다 3분만 허용 ③ (선택) 30분 후 10분 휴식'
                  : '쇼츠는 카카오톡 앱 안에서만 돌아가요. Isle이 확실히 막는 방법은 '
                      '① iPhone 앱 차단 ② 5분마다 3분만 허용 ③ (선택) 30분 후 10분 휴식입니다.',
              style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
            ),
            if (insight != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _riskColor(insight.riskLevel).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _riskColor(insight.riskLevel).withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(insight.headline, style: IsleText.body()),
                    const SizedBox(height: 4),
                    Text(insight.detail, style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChipTip(
                  label: '최강',
                  tip: Platform.isAndroid ? '접근성 · 카카오톡' : 'Screen Time · 카카오톡',
                ),
                _ChipTip(label: '쇼츠 끊기', tip: '5분 리필 3분'),
                _ChipTip(label: '인식', tip: '연속 시청 분석'),
              ],
            ),
            const SizedBox(height: 14),
            if (IsleApplePlatform.isNativeBlockHost)
              SizedBox(
                width: double.infinity,
                height: IsleSize.minTouchTarget,
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            final r = await KakaoShortsPresetService.applyMicroRefillSchedule();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  r.statusMessage(isIos: Platform.isIOS || Platform.isMacOS),
                                ),
                                duration: const Duration(seconds: 6),
                              ),
                            );
                            if (r.needsScreenTimePick) {
                              context.push(IsleRoutes.blockScheduleEdit(r.schedule.id));
                            }
                          }),
                  icon: const Icon(Icons.loop),
                  label: const Text('5분 리필 스케줄 만들기'),
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _pomodoro,
              onChanged: _busy
                  ? null
                  : (v) => _run(() async {
                        await KakaoShortsAddictionStore.setPomodoroEnabled(v);
                        if (!context.mounted) return;
                        if (v) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '30분 누적 후 10분 휴식 알림 — 휴식 때는 「항상 막기」에 카카오톡을 넣는 게 가장 확실해요',
                              ),
                              duration: Duration(seconds: 5),
                            ),
                          );
                        }
                      }),
              title: Text('30분 이용 → 10분 휴식', style: IsleText.body()),
              subtitle: Text(
                KakaoShortsAddictionStore.isOnBreak
                    ? '휴식 중 (${KakaoShortsAddictionStore.breakRemaining?.inMinutes ?? 0}분 남음)'
                    : '세션 기록과 함께 집중 창 누적',
                style: IsleText.caption(color: IsleColors.muted),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              if (_sessionOpen) {
                                await KakaoShortsAddictionStore.endOpenSession();
                              } else {
                                await KakaoShortsAddictionStore.startManualSession();
                              }
                            }),
                    icon: Icon(_sessionOpen ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                    label: Text(_sessionOpen ? '쇼츠 세션 종료' : '쇼츠 세션 시작'),
                  ),
                ),
                const SizedBox(width: 8),
                if (!Platform.isAndroid)
                  TextButton(
                    onPressed: _busy ? null : () => _run(KakaoShortsPresetService.enableSafariKakaoDomain),
                    child: const Text('Safari kakao.com'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipTip extends StatelessWidget {
  const _ChipTip({required this.label, required this.tip});
  final String label;
  final String tip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: Chip(
        label: Text(label, style: IsleText.caption()),
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: IsleColors.ocean100),
      ),
    );
  }
}
