import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import 'share_queue_cc_card.dart';

/// ② 받기 — 카톡·Safari 공유 + URL 직접 붙여넣기
class ShareInboundLinksCard extends StatelessWidget {
  const ShareInboundLinksCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: const Color(0xFFFFF9E6),
          child: ListTile(
            leading: const Icon(Icons.ios_share, color: IsleColors.ocean700),
            title: const Text('카카오톡·Safari에서 보내기'),
            subtitle: const Text(
              '다른 앱 「공유」→ Isle 선택 → 링크가 여기로 들어와요\n'
              '유튜브·글·인스타 링크 모두 가능',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/home/share/playlists'),
          ),
        ),
        const SizedBox(height: 10),
        const ShareQueueCcCard(),
      ],
    );
  }
}
