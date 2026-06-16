import 'package:flutter/material.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/youtube/youtube_focus_time_store.dart';

Future<void> showYoutubeFocusTimeSavedDialog(BuildContext context) async {
  final label = YoutubeFocusTimeStore.formatSavedLabel();
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text('🎉 오늘 아낀 시간', style: IsleText.title()),
      content: Text(
        '오늘 도파민의 유혹을 이겨내고 $label을 아끼셨습니다!',
        style: IsleText.body(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('좋아요'),
        ),
      ],
    ),
  );
}
