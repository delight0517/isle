import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/isle_app_log_service.dart';
import '../core/services/isle_app_update_provider.dart';

/// 앱 첫 프레임 후 catalog/live/isle.json 확인 → 새 버전이면 다이얼로그
class WdmAppUpdateBootstrap extends ConsumerStatefulWidget {
  const WdmAppUpdateBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WdmAppUpdateBootstrap> createState() => _WdmAppUpdateBootstrapState();
}

class _WdmAppUpdateBootstrapState extends ConsumerState<WdmAppUpdateBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_startupCheck()));
  }

  Future<void> _startupCheck() async {
    if (!mounted) return;
    try {
      final updater = ref.read(wdmAppUpdaterProvider);
      if (updater.shouldSkipBackgroundCheck()) return;
      await updater.showUpdateDialogIfNeeded(context);
    } catch (e, st) {
      IsleAppLogService.log(
        'startup app update check: $e',
        level: IsleLogLevel.debug,
      );
      debugPrint('WdmAppUpdateBootstrap: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
