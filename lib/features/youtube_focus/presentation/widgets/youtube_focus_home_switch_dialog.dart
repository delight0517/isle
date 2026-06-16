import 'package:flutter/material.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/isle_user_defaults.dart';

/// 첫 진입 시 — 기존 유튜브 앱 대신 홈에 두라는 가벼운 가이드
Future<void> showYoutubeFocusHomeSwitchDialog(BuildContext context) async {
  if (IsleUserDefaults.hasSeenYoutubeFocusHomeSwitchGuide) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text('홈 화면 스위칭', style: IsleText.title()),
      content: Text(
        '기존 YouTube 앱은 폴더 깊숙이 숨기거나 삭제하시고, '
        '딱 일주일만 스마트폰 홈 화면에 Isle 몰입 모드를 두고 '
        '유튜브가 보고 싶을 때마다 여기를 켜 보세요.\n\n'
        '알고리즘 없이 검색 → 요약 먼저 읽기 → 필요할 때만 재생.',
        style: IsleText.body(),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await IsleUserDefaults.setHasSeenYoutubeFocusHomeSwitchGuide(true);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('일주일 도전해 볼게요'),
        ),
      ],
    ),
  );
}
