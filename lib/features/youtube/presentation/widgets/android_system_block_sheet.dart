import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/platform/platform_block_intent.dart';

/// Android — Screen Time 시트 대체
Future<void> showAndroidSystemBlockSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('다른 앱·${PlatformBlockCopy.externalBrowserName}의 YouTube', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          Text(
            'Isle WebView는 앱 안 한도·스케줄로 막을 수 있어요.\n'
            'Chrome·YouTube 앱은 Android 시스템 설정에서 제한하세요.',
            style: IsleText.body(color: IsleColors.muted),
          ),
          const SizedBox(height: 12),
          _step('1', '설정 → 디지털 웰빙 → 앱 타이머'),
          _step('2', 'YouTube · Chrome 선택 → 시간 제한 또는 일시정지'),
          _step('3', '(선택) Private DNS로 youtube.com 필터'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(PlatformBlockCopy.settingsRoute);
            },
            child: const Text('자세한 Android 안내'),
          ),
        ],
      ),
    ),
  );
}

Widget _step(String n, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: IsleColors.ocean500,
            child: Text(n, style: IsleText.badge(color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: IsleText.body())),
        ],
      ),
    );
