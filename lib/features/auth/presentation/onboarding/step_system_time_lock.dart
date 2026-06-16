import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/intervention/app_intervention_service.dart';
import '../../../../core/intervention/browser_youtube_tracking_prefs.dart';
import '../../../../core/platform/isle_apple_platform.dart';
import '../../../../core/platform/ios_screen_time_service.dart';
import '../../../../core/services/setup_journey_service.dart';
import '../../../guide/presentation/widgets/youtube_isle_core_guide.dart';

/// 첫 설치 — 브라우저 유튜브 차단 → Isle 시청·트래킹 (온보딩 2단계)
class StepSystemTimeLock extends StatefulWidget {
  const StepSystemTimeLock({super.key});

  @override
  State<StepSystemTimeLock> createState() => _StepSystemTimeLockState();
}

class _StepSystemTimeLockState extends State<StepSystemTimeLock> {
  bool _busy = false;

  Future<void> _markDone() async {
    await SetupJourneyService.markStepDone('system_apps_lock');
    await SetupJourneyService.markStepDone('browser_youtube_tracking');
  }

  Future<void> _openTrackingWizard() async {
    setState(() => _busy = true);
    try {
      if (mounted) await context.push('/settings/browser-youtube-tracking');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quickBrowserBlock() async {
    setState(() => _busy = true);
    try {
      if (IsleApplePlatform.isNativeBlockHost) {
        if (Platform.isAndroid) {
          await AppInterventionService.ensureAuthorized();
          await AppInterventionService.pickApps();
        } else {
          await AppInterventionService.ensureAuthorized();
          await IosScreenTimeService.clearAllWebContentFilters();
          await BrowserYoutubeTrackingPrefs.setOsWebBlockApplied(false);
          await AppInterventionService.pickApps();
        }
      }
      await _markDone();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '핵심 설정\n(2/5)',
            style: IsleText.title(color: IsleColors.ocean900),
          ),
          const SizedBox(height: 12),
          if (_busy)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else
            YoutubeIsleCoreGuide(
              onPrimaryAction: _openTrackingWizard,
              primaryLabel: '3단계 설정 마법사',
              onSecondaryAction: IsleApplePlatform.isNativeBlockHost ? _quickBrowserBlock : _markDone,
              secondaryLabel: IsleApplePlatform.isNativeBlockHost
                  ? 'YouTube 앱만 빠르게 선택 (Isle WebView는 유지)'
                  : '나중에 · 설정에서 할게요',
            ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _markDone,
              child: Text('건너뛰기', style: IsleText.caption(color: IsleColors.muted)),
            ),
          ),
        ],
      ),
    );
  }
}
