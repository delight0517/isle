import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/isle_navigation.dart';
import '../../core/navigation/schedule_overlay_navigation.dart';
import '../../core/constants/app_typography.dart';
import '../../core/localization/schedule_strings.dart';
import '../../core/platform/ios_internal_schedule_lock_controller.dart';
import '../../core/platform/ios_screen_time_service.dart';
import '../../core/platform/isle_apple_platform.dart';

/// L3 — 스케줄 시간인데 OS 쉴드가 꺼져 있으면 Isle UI만 전면 차단.
class IosScheduleLockOverlayHost extends StatefulWidget {
  const IosScheduleLockOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  State<IosScheduleLockOverlayHost> createState() => _IosScheduleLockOverlayHostState();
}

class _IosScheduleLockOverlayHostState extends State<IosScheduleLockOverlayHost>
    with WidgetsBindingObserver {
  bool _visible = false;
  Timer? _wake;

  @override
  void initState() {
    super.initState();
    if (_enabled) {
      WidgetsBinding.instance.addObserver(this);
      _refresh();
      _scheduleWake();
    }
  }

  bool get _enabled => Platform.isIOS && IsleApplePlatform.isScreenTimeHost;

  @override
  void dispose() {
    _wake?.cancel();
    if (_enabled) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _scheduleWake();
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _wake?.cancel();
      _wake = null;
    }
  }

  /// [Volt] 45초 폴링 대신 최대 60초 one-shot wake.
  void _scheduleWake() {
    _wake?.cancel();
    if (!_enabled || !mounted) return;
    _wake = Timer(const Duration(seconds: 45), () {
      if (!mounted) return;
      _refresh().then((_) => _scheduleWake());
    });
  }

  Future<void> _refresh() async {
    if (!_enabled) return;
    final show = await IosInternalScheduleLockController.shouldShowOverlay();
    if (!mounted) return;
    if (show != _visible) setState(() => _visible = show);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible) const _IosInternalLockOverlay(),
      ],
    );
  }
}

class _IosInternalLockOverlay extends StatelessWidget {
  const _IosInternalLockOverlay();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.shield_outlined, size: 56, color: IsleColors.ocean500),
              const SizedBox(height: 16),
              Text(
                ScheduleStrings.of(context).t('overlay_title'),
                style: IsleText.title(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                '${ScheduleStrings.of(context).t('overlay_body')}\n'
                'Isle · Screen Time',
                style: IsleText.body(color: IsleColors.ocean100),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => IosScreenTimeService.openScreenTimeSettings(),
                icon: const Icon(Icons.settings),
                label: const Text('iOS Screen Time 열기'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => openBlockScheduleFromOverlay(context),
                icon: const Icon(Icons.schedule, color: Colors.white),
                label: Text(
                  ScheduleStrings.of(context).t('hub_title'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () =>
                    IsleNavigation.push('/settings/iphone-blocking', from: context),
                child: const Text('iPhone 차단 기능 안내'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
