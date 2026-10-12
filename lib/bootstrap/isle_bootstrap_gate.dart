import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_release_info.dart';
import '../core/constants/app_typography.dart';
import '../core/guard/isle_bootstrap_state.dart';
import '../core/services/isle_app_log_service.dart';
import 'isle_deferred_os_sync.dart';

/// [Volt] `runApp` 직후 UI를 먼저 띄우고, 무거운 Hive·스토어 부트스트랩은 첫 프레임 뒤에 실행.
class IsleBootstrapGate extends StatefulWidget {
  const IsleBootstrapGate({
    super.key,
    required this.bootstrap,
    required this.child,
  });

  final Future<void> Function() bootstrap;
  final Widget child;

  @override
  State<IsleBootstrapGate> createState() => _IsleBootstrapGateState();
}

class _IsleBootstrapGateState extends State<IsleBootstrapGate> {
  Object? _error;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  Future<void> _run() async {
    try {
      await widget.bootstrap();
      if (!mounted) return;
      setState(() => _ready = true);
      IsleDeferredOsSyncService.scheduleAfterUiReady();
    } catch (e, st) {
      IsleBootstrapState.markFailure('bootstrap_gate');
      IsleAppLogService.log('Bootstrap gate failed: $e', level: IsleLogLevel.error, stack: st);
      if (!mounted) return;
      setState(() {
        _error = e;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _ready = false;
    });
    await _run();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: IsleColors.ocean900,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Text('Isle', style: IsleText.title(color: Colors.white)),
                  const SizedBox(height: 12),
                  Text(
                    '시작 중 문제가 생겼어요.\n다시 시도하거나 앱을 재설치해 주세요.',
                    style: IsleText.body(color: IsleColors.ocean100),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _retry, child: const Text('다시 시도')),
                  const Spacer(),
                  Text(
                    AppReleaseInfo.label,
                    textAlign: TextAlign.center,
                    style: IsleText.caption(color: IsleColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: IsleColors.ocean900,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              Text('Isle', style: IsleText.title(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                '준비 중…',
                style: IsleText.body(color: IsleColors.ocean100),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: IsleColors.gold500,
                ),
              ),
              const Spacer(flex: 4),
              Text(
                AppReleaseInfo.label,
                style: IsleText.caption(color: IsleColors.muted),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
