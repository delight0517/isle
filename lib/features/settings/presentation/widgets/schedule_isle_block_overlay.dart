import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/schedule_overlay_navigation.dart';
import '../../../../core/block_schedule/models/block_schedule.dart';
import '../../../../core/block_schedule/schedule_active_service.dart';
import '../../../../core/block_schedule/schedule_app_targets_store.dart';
import '../../../../core/block_schedule/schedule_target_access_guard.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/explorer/explorer_site.dart';

/// 스케줄 슬롯 차단·번들 한도 — WebView 위 오버레이
class ScheduleIsleBlockOverlay extends StatelessWidget {
  const ScheduleIsleBlockOverlay({
    super.key,
    required this.site,
    this.instagramDmOnly = false,
  });

  final ExplorerSite site;
  final bool instagramDmOnly;

  @override
  Widget build(BuildContext context) {
    // YouTube 전용 탭 — [YoutubeWatchLimitOverlay] 단일 오버레이
    if (site.isYoutube) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: ScheduleTargetAccessGuard.isExplorerBlocked(
        site,
        instagramDmOnly: instagramDmOnly,
      ),
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        final primary = _primarySchedule();
        final (title, body) = _copy(primary);
        return Material(
          color: Colors.black.withValues(alpha: 0.72),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phonelink_lock, size: 56, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: IsleText.subtitle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      body,
                      style: IsleText.caption(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => openBlockScheduleFromOverlay(
                        context,
                        scheduleId: primary?.id,
                      ),
                      child: Text(primary != null ? '이 스케줄 편집' : '스케줄 목록'),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text('나가기', style: IsleText.body(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  BlockSchedule? _primarySchedule() {
    final active = ScheduleActiveService.activeSchedulesNow();
    final targetId = switch (site) {
      _ when site.isInstagram =>
        instagramDmOnly ? 'isle_instagram_dm' : 'isle_instagram',
      _ when site.isBrunch => 'isle_brunch',
      _ when site.isYoutube => 'isle_youtube',
      _ => 'isle_youtube',
    };
    for (final s in active) {
      final e = ScheduleAppTargetsStore.entryFor(s.id, targetId);
      if (e != null && e.blockInSlot) return s;
    }
    return active.isNotEmpty ? active.first : null;
  }

  (String, String) _copy(BlockSchedule? primary) {
    if (site.isInstagram) {
      if (instagramDmOnly) {
        return (
          'Isle · Instagram DM 차단 중',
          '메시지함 타깃이 켜져 있어요.\n스케줄 편집에서 DM·피드를 각각 설정할 수 있어요.',
        );
      }
      return (
        'Isle · Instagram 차단 중',
        '피드·탐색 타깃이 켜져 있어요. DM은 별도 타깃으로 막을 수 있어요.',
      );
    }
    if (site.isBrunch) {
      return (
        'Isle · Brunch 차단 중',
        '이 스케줄에서 브런치 읽기를 막아 두었어요.',
      );
    }
    if (site == ExplorerSite.custom) {
      return (
        'Isle · 웹 탐색 차단 중',
        '아침 집중 스케줄이 켜져 있어요.\n'
            'Isle Safari(웹)와 유튜브·인스타 등 Isle 안 탐색이 막혀 있어요.',
      );
    }
    return ('스케줄 차단 중', '스케줄 편집에서 해제할 수 있어요.');
  }
}
