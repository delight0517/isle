import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/library/models/library_entry.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 「나중에 볼」 영상 자막 기반 브이로그 글 — 보기·복사·공유
class GeneratedVlogPostScreen extends StatelessWidget {
  const GeneratedVlogPostScreen({super.key, required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final post = entry.generatedPost?.trim() ?? '';
    return Scaffold(
      appBar: IsleAppBar(
        title: '브이로그 글',
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: '복사',
            onPressed: post.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: post));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('클립보드에 복사했어요')),
                    );
                  },
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: '공유',
            onPressed: post.isEmpty
                ? null
                : () => Share.share('${entry.title}\n\n$post', subject: entry.title),
          ),
        ],
      ),
      body: post.isEmpty
          ? Center(
              child: Text('아직 생성된 글이 없어요', style: IsleText.body(color: IsleColors.muted)),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(entry.title, style: IsleText.subtitle()),
                if (entry.channelName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(entry.channelName, style: IsleText.caption(color: IsleColors.muted)),
                ],
                const SizedBox(height: 16),
                Text(post, style: IsleText.body().copyWith(height: 1.6)),
                const SizedBox(height: 24),
                Text('자막(CC) 기반 · 원문과 다를 수 있어요', style: IsleText.caption(color: IsleColors.muted)),
              ],
            ),
    );
  }
}
