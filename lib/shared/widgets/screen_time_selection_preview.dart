import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/platform/isle_apple_platform.dart';

/// iOS: FamilyControls `Label` 행(실제 앱·카테고리 이름). 그 외: 텍스트 칩.
class ScreenTimeSelectionPreview extends StatelessWidget {
  const ScreenTimeSelectionPreview({
    super.key,
    required this.encoded,
    this.textFallbackLabels = const [],
    this.maxCount = 10,
    this.height = 36,
  });

  final String? encoded;
  final List<String> textFallbackLabels;
  final int maxCount;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enc = encoded;
    if (enc == null || enc.isEmpty) {
      return _textChips(textFallbackLabels);
    }

    if (!kIsWeb &&
        IsleApplePlatform.isScreenTimeHost &&
        (Platform.isIOS || Platform.isMacOS)) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: UiKitView(
          viewType: 'isle-screen-time-labels',
          layoutDirection: TextDirection.ltr,
          creationParams: <String, dynamic>{
            'encoded': enc,
            'maxCount': maxCount,
          },
          creationParamsCodec: const StandardMessageCodec(),
        ),
      );
    }

    if (textFallbackLabels.isNotEmpty) {
      return _textChips(textFallbackLabels);
    }

    if (Platform.isAndroid && enc.contains('.')) {
      final labels = enc
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .map((p) {
            final parts = p.split('.');
            return parts.isNotEmpty ? parts.last : p;
          })
          .toList();
      return _textChips(labels);
    }

    return const SizedBox.shrink();
  }

  Widget _textChips(List<String> labels) {
    if (labels.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labels.take(maxCount).map((l) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: IsleColors.ocean100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: IsleColors.ocean500.withValues(alpha: 0.25)),
          ),
          child: Text(l, style: IsleText.caption(color: IsleColors.ocean700)),
        );
      }).toList(),
    );
  }
}
