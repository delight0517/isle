import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_release_info.dart';
import '../../core/constants/app_typography.dart';
import '../../core/perf/isle_heavy_work_controller.dart';
import '../../core/perf/isle_perf_log_service.dart';

/// 렉·무거운 작업 — 설득형 전면 오버레이
class IsleHeavyWorkOverlayHost extends StatelessWidget {
  const IsleHeavyWorkOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        ListenableBuilder(
          listenable: IsleHeavyWorkController.instance,
          builder: (context, _) {
            final snap = IsleHeavyWorkController.instance.snapshot;
            if (!snap.visible) return const SizedBox.shrink();
            return _HeavyWorkOverlay(snap: snap);
          },
        ),
      ],
    );
  }
}

class _HeavyWorkOverlay extends StatelessWidget {
  const _HeavyWorkOverlay({required this.snap});

  final IsleHeavyWorkSnapshot snap;

  Future<void> _copyForCursor(BuildContext context) async {
    final text = await IslePerfLogService.buildDelayReportForCursor();
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          Platform.isIOS || Platform.isAndroid
              ? '딜레이 로그 복사됨 — Cursor 채팅에 붙여넣어 주세요'
              : '딜레이 로그 복사됨 — Cursor에 붙여넣기',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainPct = snap.remainingPercent;
    final remainSec = snap.estimatedRemainingSec;
    final progressLabel = remainSec != null
        ? '약 $remainPct% 남음 · ~${remainSec}초'
        : '약 $remainPct% 남음';

    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: IsleColors.gold500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    snap.title.isEmpty ? '중요 작업 처리 중' : snap.title,
                    style: IsleText.subtitle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    snap.why.isEmpty
                        ? '지금 이 작업이 최우선이에요. 끝나면 바로 다시 쓸 수 있어요.'
                        : snap.why,
                    style: IsleText.caption(color: Colors.white70).copyWith(height: 1.45),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: snap.progress.clamp(0.05, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      color: IsleColors.ocean500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    progressLabel,
                    style: IsleText.body(color: IsleColors.gold500),
                  ),
                  if (snap.stepLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      snap.stepLabel,
                      style: IsleText.caption(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (snap.severe && !snap.fromJank) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '렉이 평소보다 길어요',
                            style: IsleText.body(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '원인·작업 내역을 파일로 남겼어요. '
                            '아래 버튼으로 복사한 뒤 Cursor에 붙여넣으면 다음 수정에 쓸 수 있어요.',
                            style: IsleText.caption(color: Colors.white70).copyWith(height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => _copyForCursor(context),
                            icon: const Icon(Icons.content_copy, size: 18),
                            label: const Text('딜레이 로그 보내기 (개발자용)'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    AppReleaseInfo.label,
                    style: IsleText.caption(color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
