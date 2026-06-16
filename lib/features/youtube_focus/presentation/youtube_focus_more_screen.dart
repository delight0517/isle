import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_typography.dart';
import '../../../core/platform/platform_block_intent.dart';
/// `main_youtube_focus` 전용 — 전체 설정 트리 없이 자주 쓰는 항목만.
class YoutubeFocusMoreScreen extends StatelessWidget {
  const YoutubeFocusMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black87;
    final hint = isDark ? Colors.white54 : Colors.black45;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        foregroundColor: fg,
        title: Text('설정 · 도구', style: IsleText.subtitle(color: fg)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.public_off_outlined, color: fg),
            title: Text(PlatformBlockCopy.settingsTileTitle, style: IsleText.body(color: fg)),
            subtitle: Text(PlatformBlockCopy.settingsTileSubtitle, style: IsleText.caption(color: hint)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => context.push(
              PlatformBlockCopy.isAndroid
                  ? '/youtube-focus/more/android-system-block'
                  : '/youtube-focus/more/safari-youtube-os',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule, color: fg),
            title: Text('차단 스케줄', style: IsleText.body(color: fg)),
            subtitle: Text('앱 내 잠금 · Mac 동기화', style: IsleText.caption(color: hint)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => context.push('/youtube-focus/more/schedules'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.timer_outlined, color: fg),
            title: Text('유튜브 시청 한도', style: IsleText.body(color: fg)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => context.push('/youtube-focus/more/youtube-limits'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.receipt_long_outlined, color: fg),
            title: Text('앱 로그', style: IsleText.body(color: fg)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => context.push('/youtube-focus/more/app-log'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.save_alt_outlined, color: fg),
            title: Text('데이터 백업', style: IsleText.body(color: fg)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => context.push('/youtube-focus/more/backup'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.bug_report_outlined, color: fg),
            title: Text('디버그', style: IsleText.body(color: fg)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => context.push('/youtube-focus/more/debugger'),
          ),
          const SizedBox(height: 24),
          Text(
            '메인 Isle 앱(피드·섬)은 App Store / TestFlight 빌드를 쓰면 됩니다.',
            textAlign: TextAlign.center,
            style: IsleText.caption(color: hint),
          ),
        ],
      ),
    );
  }
}
