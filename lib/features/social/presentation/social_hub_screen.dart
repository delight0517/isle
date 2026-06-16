import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 소셜 허브 — 인스타·페이스북·Isle 프로필
class SocialHubScreen extends StatelessWidget {
  const SocialHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IsleAppBar(title: '소셜'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '구독 중인 계정·Isle 게시·프로필 미리보기',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 16),
          _Card(
            icon: Icons.grid_on,
            color: IsleColors.gold500,
            title: '내 게시물 모음',
            subtitle: '프로필에 올린 사진·글·영상 그리드',
            onTap: () => context.push('/social/profile/preview'),
          ),
          _Card(
            icon: Icons.camera_alt_outlined,
            color: const Color(0xFFE1306C),
            title: '인스타그램',
            subtitle: '구독 피드 · 관심 없음 · 스토리 공유',
            onTap: () => context.push('/social/instagram'),
          ),
          _Card(
            icon: Icons.facebook,
            color: const Color(0xFF1877F2),
            title: '페이스북',
            subtitle: '모바일 피드 (앱 안)',
            onTap: () => context.push(
              '/explore/browser?site=facebook&url=${Uri.encodeComponent('https://m.facebook.com/')}',
            ),
          ),
          _Card(
            icon: Icons.person_outline,
            color: IsleColors.ocean500,
            title: '내 Isle 프로필',
            subtitle: '사진·글·영상 게시 · 팔로워용',
            onTap: () => context.push('/social/profile'),
          ),
          _Card(
            icon: Icons.visibility_outlined,
            color: IsleColors.gold500,
            title: '다른 사람이 보는 내 프로필',
            subtitle: '미리보기',
            onTap: () => context.push('/social/profile/preview'),
          ),
          _Card(
            icon: Icons.dynamic_feed_outlined,
            color: IsleColors.ocean700,
            title: 'Isle 피드',
            subtitle: '팔로워·내 게시물',
            onTap: () => context.push('/social/feed'),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
        title: Text(title, style: IsleText.subtitle()),
        subtitle: Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
