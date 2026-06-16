import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/block_schedule/block_focus_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
/// 3단계 체크리스트 — 무엇이 남았는지 명확히
class BlockSetupSteps extends StatelessWidget {
  const BlockSetupSteps({
    super.key,
    required this.status,
    required this.onRequestAuth,
    required this.onPickApps,
    required this.onAddSchedule,
  });

  final BlockFocusStatus status;
  final VoidCallback onRequestAuth;
  final VoidCallback onPickApps;
  final VoidCallback onAddSchedule;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('어떻게 작동하나요?', style: IsleText.subtitle()),
          const SizedBox(height: 4),
          Text(
            '① 막을 앱 선택 → ② 시간표 → ③ 그 시간에 앱 아이콘이 열리지 않음',
            style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
          ),
          const Divider(height: 24),
          _step(
            done: status.osAuthorized,
            title: 'Screen Time 허용',
            subtitle: status.osAvailable ? 'Apple 권한 (한 번만)' : '미지원 빌드',
            onTap: status.osAuthorized ? null : onRequestAuth,
          ),
          _step(
            done: status.hasApps,
            title: 'Instagram 등 앱 선택',
            subtitle: status.hasApps
                ? '${status.appCount}개 앱 · 피커에서 Instagram 앱을 고르세요'
                : 'WebView가 아닌 실제 앱',
            onTap: status.hasApps ? () => context.push('/settings/external-apps') : onPickApps,
          ),
          _step(
            done: status.hasSchedule && status.masterOn,
            title: '차단 시간표',
            subtitle: status.scheduleActiveNow
                ? '지금 이 시간대에 차단 중'
                : (status.hasSchedule
                    ? '${status.scheduleCount}개 스케줄 · 지금은 해당 시간 아님'
                    : '예: 밤 9시–아침 7시'),
            onTap: onAddSchedule,
          ),
        ],
      ),
    );
  }

  Widget _step({
    required bool done,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: done ? IsleColors.grassDeep : IsleColors.sand100,
                child: Icon(
                  done ? Icons.check : Icons.circle_outlined,
                  size: 18,
                  color: done ? Colors.white : IsleColors.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
                    Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: IsleColors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
