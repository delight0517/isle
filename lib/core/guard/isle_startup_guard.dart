import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../services/isle_app_log_service.dart';
import '../services/isle_debug_log_service.dart';

/// 앱 전체 크래시·회색 ErrorWidget 대신 복구 화면
class IsleStartupGuard {
  IsleStartupGuard._();

  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;

    ErrorWidget.builder = (details) {
      IsleAppLogService.log(
        'ErrorWidget: ${details.exception}',
        level: IsleLogLevel.error,
        stack: details.stack,
      );
      unawaited(
        IsleDebugLogService.recordCrash(
          kind: 'error_widget',
          message: details.exception.toString(),
          stack: details.stack,
        ),
      );
      return _RecoveryErrorView(details: details);
    };

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      IsleAppLogService.log(
        details.exceptionAsString(),
        level: IsleLogLevel.error,
        stack: details.stack,
      );
    };
  }
}

class _RecoveryErrorView extends StatelessWidget {
  const _RecoveryErrorView({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48, color: IsleColors.gold500),
              const SizedBox(height: 16),
              Text('화면을 불러오지 못했어요', style: IsleText.subtitle(color: IsleColors.ocean900)),
              const SizedBox(height: 8),
              Text(
                '데이터는 기기에 남아 있습니다. 아래에서 다시 시도하거나 피드로 이동하세요.',
                style: IsleText.body(color: IsleColors.muted),
              ),
              const Spacer(),
              if (kDebugMode) ...[
                Text(
                  '${details.exception}',
                  style: IsleText.caption(color: IsleColors.danger),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: () {
                  (context as Element).markNeedsBuild();
                },
                child: const Text('이 화면 다시 시도'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/feed'),
                child: const Text('피드로 이동'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
