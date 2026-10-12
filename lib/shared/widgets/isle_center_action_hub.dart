import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/navigation/center_nav_long_press.dart';
import '../../core/platform/platform_block_intent.dart';
import '../../core/youtube/youtube_clipboard_watch.dart';
import 'isle_sheet.dart';

/// 하단 중앙 Isle 버튼 탭 — 자주 쓰는 기능 (바텀 시트)
void showIsleCenterActionHub(BuildContext context) {
  HapticFeedback.mediumImpact();
  showIsleModalSheet<void>(
    context: context,
    builder: (sheetCtx) => _CenterActionHubSheet(
      sheetContext: sheetCtx,
      hostContext: context,
    ),
  );
}

class _CenterActionHubSheet extends StatelessWidget {
  const _CenterActionHubSheet({
    required this.sheetContext,
    required this.hostContext,
  });

  final BuildContext sheetContext;
  final BuildContext hostContext;

  void _closeThen(void Function(BuildContext host) action) {
    Navigator.pop(sheetContext);
    action(hostContext);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text('빠른 실행', style: IsleText.title()),
          const SizedBox(height: 6),
          Text(
            '가운데 Isle 탭을 누르면 언제든 열 수 있어요. 길게 누르면 유튜브·인스타 바로 열기.',
            style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          _ActionRow(
            icon: Icons.qr_code_scanner,
            iconColor: const Color(0xFF1DB954),
            title: 'QR 스캔',
            subtitle: '카메라로 링크 열기',
            onTap: () => _closeThen((host) => host.push('/home/share/qr')),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.play_circle_filled,
            iconColor: const Color(0xFFFF0000),
            title: 'YouTube',
            subtitle: '앱 안에서 시청',
            onTap: () => _closeThen(openCenterNavYoutube),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.headphones,
            iconColor: const Color(0xFF1DB954),
            title: '유튜브 음성',
            subtitle: '듣기 전용 모드',
            onTap: () => _closeThen((host) => host.push('/youtube/podcast')),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.camera_alt_outlined,
            iconColor: const Color(0xFFE1306C),
            title: 'Instagram',
            subtitle: '피드·DM',
            onTap: () => _closeThen(openCenterNavInstagram),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.explore_outlined,
            iconColor: const Color(0xFF0A84FF),
            title: PlatformBlockCopy.inAppBrowserNavLabel,
            subtitle: '구글 등 웹 검색',
            onTap: () => _closeThen(
              (host) => host.push(
                '/explore/browser?site=custom&url=${Uri.encodeComponent('https://www.google.com')}',
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.content_paste_go_outlined,
            iconColor: const Color(0xFFFF0000),
            title: '복사한 YouTube 열기',
            subtitle: '클립보드에 URL이 있을 때',
            onTap: () => _closeThen((host) => YoutubeClipboardWatch.pasteAndPlay(host)),
          ),
          const Divider(height: 28),
          _ActionRow(
            icon: Icons.shield_outlined,
            iconColor: IsleColors.ocean700,
            title: '차단',
            subtitle: '스케줄·앱 잠금',
            onTap: () => _closeThen((host) => host.go('/home/block')),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.landscape_outlined,
            iconColor: IsleColors.ocean500,
            title: '나의 Isle',
            subtitle: '콘텐츠·관리',
            onTap: () => _closeThen((host) => host.go('/home/my-isle')),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: IsleSize.minTouchTarget,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                showCenterNavPickerSheet(hostContext);
              },
              icon: const Icon(Icons.touch_app_outlined, size: 18),
              label: const Text('길게 누르기 동작 바꾸기'),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: IsleColors.ocean100),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
                      Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: IsleColors.muted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
