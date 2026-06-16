import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/isle_routes.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/focus/isle_product_focus.dart';
import '../../../core/intervention/browser_youtube_tracking_prefs.dart';
import '../../../core/platform/platform_block_intent.dart';
import '../../../core/youtube/youtube_clipboard_watch.dart';

/// 탭 「집중」— 1·2·3대 기능 허브
class FocusHubScreen extends StatelessWidget {
  const FocusHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = PlatformBlockCopy.externalBrowserName;
    final trackingDone = BrowserYoutubeTrackingPrefs.hasCompletedEncouragementFlow;

    return Scaffold(
      backgroundColor: IsleColors.sand100,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('집중 · 시간 통제', style: IsleText.subtitle(color: IsleColors.ocean900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text(
            '유튜브는 Isle 안에서만 보고, 밖의 앱·브라우저는 막아 두세요.',
            style: IsleText.body(color: IsleColors.muted).copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          _pillarCard(
            context,
            step: '1',
            color: const Color(0xFF4A6FA5),
            icon: Icons.shield_outlined,
            title: '다른 앱 차단·한도',
            subtitle: '앱별 N분 · 개입 화면 · Instagram 등',
            route: '/settings/app-usage-limits',
          ),
          _pillarCard(
            context,
            step: '2',
            color: const Color(0xFF2D6A5A),
            icon: Icons.track_changes,
            title: '$browser 유튜브 → Isle',
            subtitle: trackingDone ? '트래킹 설정 완료' : '브라우저 차단 후 시간 기록',
            route: PlatformBlockCopy.settingsRoute,
            badge: trackingDone ? null : '권장',
          ),
          _pillarCard(
            context,
            step: '3',
            color: const Color(0xFFFF0000),
            icon: Icons.play_circle_outline,
            title: 'Isle에서 유튜브 보기',
            subtitle: 'WebView · 시청 한도 · 차단 스케줄',
            onTap: () => context.push('/youtube/browser'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => context.push('/youtube/browser'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.play_arrow, size: 28),
              label: const Text('지금 유튜브 열기'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => YoutubeClipboardWatch.pasteAndPlay(context),
                  icon: const Icon(Icons.content_paste_go, size: 18),
                  label: const Text('URL 붙여넣기'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(IsleRoutes.youtubeLimits),
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  label: const Text('시청 한도'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _quickLink(context, Icons.timer_outlined, '앱별 시간 한도', '/settings/app-usage-limits'),
          _quickLink(context, Icons.schedule, '차단 스케줄', '/settings/block-schedules'),
          _quickLink(context, Icons.bar_chart_outlined, '시청 통계', '/settings/platform-stats'),
          if (IsleProductFocus.showAdvanced) ...[
            const SizedBox(height: 16),
            Text('고급', style: IsleText.caption(color: IsleColors.muted)),
            _quickLink(context, Icons.explore_outlined, '브런치·블로그 탐색', '/explore'),
            _quickLink(context, Icons.cabin_outlined, '내 섬', '/island'),
          ],
        ],
      ),
    );
  }

  Widget _pillarCard(
    BuildContext context, {
    required String step,
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    String? route,
    VoidCallback? onTap,
    String? badge,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? (route != null ? () => context.push(route) : null),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(step, style: IsleText.subtitle(color: color)),
              ),
              const SizedBox(width: 12),
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: IsleText.subtitle()),
                    Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: IsleColors.gold500.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge, style: IsleText.caption(color: IsleColors.ocean900)),
                ),
              const Icon(Icons.chevron_right, color: IsleColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickLink(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: IsleColors.ocean700, size: 22),
      title: Text(label, style: IsleText.body()),
      trailing: const Icon(Icons.chevron_right, size: 20, color: IsleColors.muted),
      onTap: () => context.push(route),
      visualDensity: VisualDensity.compact,
    );
  }
}
