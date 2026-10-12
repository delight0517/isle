import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/isle_sheet.dart';

enum SafeBrowserBlockAction { allow15m, allowToday, keepBlocked, cancel }

/// 차단된 링크 — 임시 허용·계속 차단
Future<SafeBrowserBlockAction?> showSafeBrowserBlockSheet(
  BuildContext context, {
  required String url,
  required String message,
  String? domainLabel,
  bool allowTemporaryBypass = true,
}) {
  return showIsleModalSheet<SafeBrowserBlockAction>(
    context: context,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('이 링크는 현재 차단되어 있어요', style: IsleText.subtitle()),
          const SizedBox(height: 10),
          Text(message, style: IsleText.body(color: IsleColors.muted)),
          if (domainLabel != null) ...[
            const SizedBox(height: 6),
            Text('도메인: $domainLabel', style: IsleText.caption()),
          ],
          const SizedBox(height: 8),
          SelectableText(
            url,
            style: IsleText.caption(color: IsleColors.ocean700),
          ),
          const SizedBox(height: 16),
          if (allowTemporaryBypass) ...[
            FilledButton(
              onPressed: () => Navigator.pop(ctx, SafeBrowserBlockAction.allow15m),
              child: const Text('15분만 허용'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, SafeBrowserBlockAction.allowToday),
              child: const Text('오늘만 허용'),
            ),
            const SizedBox(height: 8),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: IsleColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '설정 잠금이 걸린 스케줄이 활성 중이라 임시 허용을 안 보여드려요. '
                '풀려면 차단 탭에서 잠금 해제 대기를 먼저 완료하세요.',
                style: IsleText.caption(color: IsleColors.danger).copyWith(height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextButton(
            onPressed: () => Navigator.pop(ctx, SafeBrowserBlockAction.keepBlocked),
            child: const Text('계속 차단'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, SafeBrowserBlockAction.cancel),
            child: const Text('취소'),
          ),
          SizedBox(height: MediaQuery.paddingOf(ctx).bottom),
        ],
      ),
    ),
  );
}

/// 처음 보는 사이트 — 열기 확인 (옵트인)
Future<bool?> showSafeBrowserUnknownSiteSheet(
  BuildContext context, {
  required String url,
}) {
  final host = Uri.tryParse(url)?.host ?? url;
  return showIsleModalSheet<bool>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('처음 보는 사이트예요', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          Text(host, style: IsleText.body()),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('열기'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
        ],
      ),
    ),
  );
}
