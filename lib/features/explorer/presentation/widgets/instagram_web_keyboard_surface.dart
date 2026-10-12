import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';

/// Instagram WebView — 키보드 애니메이션·흰 배경·입력 완료 바
class InstagramWebKeyboardSurface extends StatelessWidget {
  const InstagramWebKeyboardSurface({
    super.key,
    required this.controller,
    required this.top,
    required this.bottomSafe,
    required this.onDismissKeyboard,
  });

  final WebViewController controller;
  final double top;
  final double bottomSafe;
  final Future<void> Function() onDismissKeyboard;

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final showBar = kb > 8;

    // Scaffold가 키보드 위로 줄어든 뒤 남는 영역 전체를 흰색으로 채움 (검은 빈칸 방지)
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      bottom: bottomSafe,
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          children: [
            Expanded(child: WebViewWidget(controller: controller)),
            if (showBar) _InstagramInputAccessoryBar(onDone: onDismissKeyboard),
          ],
        ),
      ),
    );
  }
}

/// WebView 위 시스템 키보드 바로 위 — 입력 완료·키보드 내리기
class _InstagramInputAccessoryBar extends StatelessWidget {
  const _InstagramInputAccessoryBar({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: IsleColors.ocean100,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: IsleColors.ocean500.withValues(alpha: 0.22)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: IsleSize.minTouchTarget,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18, color: IsleColors.ocean700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Instagram 입력',
                      style: IsleText.caption(color: IsleColors.ocean700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onDone();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: IsleColors.ocean900,
                      textStyle: IsleText.body().copyWith(fontWeight: FontWeight.w600),
                    ),
                    child: const Text('완료'),
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
