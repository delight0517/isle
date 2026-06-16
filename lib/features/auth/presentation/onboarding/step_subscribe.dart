import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

class StepSubscribe extends StatelessWidget {
  const StepSubscribe({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('콘텐츠\n연결하기', style: IsleText.title(color: IsleColors.ocean900)),
          const SizedBox(height: 12),
          Text(
            '유튜브·브런치를 가져오면 샘플 피드 대신 진짜 콘텐츠가 채워져요. '
            '다음 화면에서 바로 시작할 수도 있어요.',
            style: IsleText.body(color: IsleColors.muted),
          ),
          const SizedBox(height: 24),
          _SourceCard(
            icon: Icons.ondemand_video,
            color: const Color(0xFFFF0000),
            title: 'YouTube',
            subtitle: '나중에 볼 · 구독 · 시청 기록',
            onTap: () => context.push('/library/sources'),
          ),
          const SizedBox(height: 12),
          _SourceCard(
            icon: Icons.article_outlined,
            color: IsleColors.ocean500,
            title: '브런치',
            subtitle: '프로필 URL로 글 가져오기',
            onTap: () => context.push('/library/sources'),
          ),
          const SizedBox(height: 12),
          _SourceCard(
            icon: Icons.play_circle_outline,
            color: IsleColors.grass,
            title: '앱 안 유튜브',
            subtitle: '시청 + 차단·한도 체험',
            onTap: () => context.push('/youtube'),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: IsleText.subtitle()),
                    Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: IsleColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
