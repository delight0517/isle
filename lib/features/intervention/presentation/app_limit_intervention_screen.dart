import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

/// 개입 화면 (딥링크·알림에서 열기) — Android 네이티브와 동일 메시지
class AppLimitInterventionScreen extends StatelessWidget {
  const AppLimitInterventionScreen({
    super.key,
    this.title = '오늘 한도에 도달했어요',
    this.body = '잠시 쉬었다가 Isle에서 의도한 콘텐츠만 보세요.',
    this.usedMinutes,
    this.limitMinutes,
  });

  final String title;
  final String body;
  final int? usedMinutes;
  final int? limitMinutes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IsleColors.sand100,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_moon_outlined, size: 72, color: IsleColors.ocean500),
              const SizedBox(height: 24),
              Text(title, style: IsleText.title(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                body,
                style: IsleText.body(color: IsleColors.muted),
                textAlign: TextAlign.center,
              ),
              if (usedMinutes != null && limitMinutes != null) ...[
                const SizedBox(height: 12),
                Text(
                  '오늘 $usedMinutes분 / 목표 $limitMinutes분',
                  style: IsleText.subtitle(color: IsleColors.ocean700),
                ),
              ],
              const SizedBox(height: 40),
              FilledButton(
                onPressed: () => context.go('/home/block'),
                style: FilledButton.styleFrom(backgroundColor: IsleColors.ocean500),
                child: const Text('집중 허브로'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.push('/youtube/browser'),
                child: const Text('Isle에서 유튜브 보기'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => context.pop(), child: const Text('닫기')),
            ],
          ),
        ),
      ),
    );
  }
}
