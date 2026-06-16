import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../explorer/explorer_site.dart';
import '../navigation/explorer_entry_guard.dart';
import '../services/isle_user_defaults.dart';
import '../social/instagram_web_config.dart';
import '../../shared/widgets/isle_sheet.dart';

/// 하단 중앙(유튜브) 버튼 길게 누르기 — 바로 열기 또는 선택
Future<void> handleCenterNavLongPress(BuildContext context) async {
  final target = IsleUserDefaults.centerNavLongPressTarget;
  switch (target) {
    case 'youtube':
      openCenterNavYoutube(context);
      return;
    case 'instagram':
      openCenterNavInstagram(context);
      return;
    case 'choose':
    default:
      await showCenterNavPickerSheet(context);
  }
}

void openCenterNavYoutube(BuildContext context) {
  HapticFeedback.lightImpact();
  final deny = ExplorerEntryGuard.denyMessageForSite(ExplorerSite.youtube);
  if (deny != null) {
    ExplorerEntryGuard.showDenial(
      context,
      deny,
      site: ExplorerSite.youtube,
    );
    return;
  }
  context.push('/youtube/browser');
}

void openCenterNavInstagram(BuildContext context) {
  HapticFeedback.lightImpact();
  context.push(InstagramWebConfig.dmBrowserRoute(dmOnly: true));
}

Future<void> showCenterNavPickerSheet(BuildContext context) async {
  HapticFeedback.mediumImpact();
  await showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('길게 누르면 바로 열기', style: IsleText.title()),
          const SizedBox(height: 6),
          Text(
            '탭 한 번은 나의 Isle로 이동합니다. 길게 누르면 아래 앱을 바로 엽니다.',
            style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          _OpenTile(
            icon: Icons.explore_outlined,
            iconColor: const Color(0xFF0A84FF),
            title: 'Safari',
            subtitle: '앱 안 웹 브라우저',
            onTap: () {
              Navigator.pop(ctx);
              context.push('/explore/browser?site=custom&url=${Uri.encodeComponent('https://www.google.com')}');
            },
          ),
          const SizedBox(height: 8),
          _OpenTile(
            icon: Icons.play_circle,
            iconColor: const Color(0xFFFF0000),
            title: 'YouTube',
            subtitle: '앱 안 브라우저로 시청',
            onTap: () {
              Navigator.pop(ctx);
              openCenterNavYoutube(context);
            },
          ),
          const SizedBox(height: 8),
          _OpenTile(
            icon: Icons.camera_alt_outlined,
            iconColor: const Color(0xFFE1306C),
            title: 'Instagram',
            subtitle: '피드·DM (WebView)',
            onTap: () {
              Navigator.pop(ctx);
              openCenterNavInstagram(context);
            },
          ),
          const Divider(height: 28),
          Text('다음부터 길게 누르면', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.touch_app_outlined),
            title: const Text('매번 선택 (지금처럼)'),
            onTap: () async {
              await IsleUserDefaults.setCenterNavLongPressTarget('choose');
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_circle_outline, color: Color(0xFFFF0000)),
            title: const Text('항상 YouTube'),
            onTap: () async {
              await IsleUserDefaults.setCenterNavLongPressTarget('youtube');
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFFE1306C)),
            title: const Text('항상 Instagram'),
            onTap: () async {
              await IsleUserDefaults.setCenterNavLongPressTarget('instagram');
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
}

class _OpenTile extends StatelessWidget {
  const _OpenTile({
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
      color: IsleColors.ocean100.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 32),
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
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
