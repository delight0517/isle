import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/share/shared_playlist_store.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// CC·AI로 만든 기사 본문 읽기
class CcArticleViewScreen extends StatelessWidget {
  const CcArticleViewScreen({super.key, required this.item});

  final SharedPlaylistItem item;

  @override
  Widget build(BuildContext context) {
    final body = item.articleBody ?? item.transcript ?? '';
    return Scaffold(
      appBar: IsleAppBar(
        title: '기사로 읽기',
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: body.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: body));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('본문을 복사했어요')),
                    );
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(item.title, style: IsleText.title()),
          if (item.channelName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.channelName, style: IsleText.caption(color: IsleColors.muted)),
          ],
          const SizedBox(height: 20),
          SelectableText(
            body.isEmpty ? '아직 기사 본문이 없어요. 받기 탭에서 CC 동기화를 실행해 주세요.' : body,
            style: IsleText.body().copyWith(height: 1.65),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push(
              '/viewer?url=${Uri.encodeComponent(item.url)}&title=${Uri.encodeComponent(item.title)}',
            ),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('영상 보기 (Isle WebView)'),
          ),
        ],
      ),
    );
  }
}
