import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import 'widgets/app_block_home_card.dart';

class AppBlockCenterScreen extends StatelessWidget {
  const AppBlockCenterScreen({super.key});

  void _openApp(BuildContext context, String bundleId) {
    context.push('/home/sns/app-blocks/$bundleId');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: IsleColors.sand100,
        appBar: const IsleAppBar(title: 'iPhone 앱 차단'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'MOA 안의 콘텐츠는 그대로 두고, iPhone에 설치된 앱은 Screen Time으로 앱별 차단·시간표·나눠 쓰기를 설정할 수 있어요.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppBlockHomeCard(
              info: AppBlockHomeCardInfo.youtube,
              onTap: () => _openApp(context, 'youtube'),
            ),
            const SizedBox(height: 10),
            AppBlockHomeCard(
              info: AppBlockHomeCardInfo.safari,
              onTap: () => _openApp(context, 'safari'),
            ),
            const SizedBox(height: 10),
            AppBlockHomeCard(
              info: AppBlockHomeCardInfo.kakao,
              onTap: () => _openApp(context, 'kakao_talk'),
            ),
            const SizedBox(height: 10),
            AppBlockHomeCard(
              info: AppBlockHomeCardInfo.youtubeMusic,
              onTap: () => _openApp(context, 'youtube_music'),
            ),
            const SizedBox(height: 12),
            Text(
              '처음 차단을 켤 때 Screen Time 권한과 대상 앱 선택이 필요합니다. 시스템 권한이 유지되는지 실제 iPhone에서도 확인해야 합니다.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: IsleColors.muted),
            ),
          ],
        ),
      );
}
