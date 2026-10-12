import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/services/isle_survival_backup_service.dart';
import '../../core/services/isle_user_defaults.dart';
import '../../core/services/setup_journey_service.dart';
import 'isle_sheet.dart';

/// 설정 → 데이터 백업 → 「폴더 변경」 → iCloud Drive 안내 (공통 문구)
class SurvivalBackupGuideSteps extends StatelessWidget {
  const SurvivalBackupGuideSteps({
    super.key,
    this.compact = false,
    this.textColor,
  });

  final bool compact;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? IsleColors.ocean900;
    final caption = textColor ?? IsleColors.ocean700;
    final steps = <(String, String)>[
      ('1', '설정 → 데이터 백업'),
      ('2', '「폴더 변경」 탭'),
      ('3', '「파일」→ iCloud Drive → Isle Backup 폴더를 만든 뒤 선택'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact)
          Text(
            '앱을 삭제해도 차단·구독·스케줄이 클라우드에 남도록 미리 지정하세요.',
            style: IsleText.body(color: color),
          ),
        if (!compact) const SizedBox(height: 12),
        ...steps.map(
          (s) => Padding(
            padding: EdgeInsets.only(bottom: compact ? 6 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: compact ? 11 : 13,
                  backgroundColor: IsleColors.gold500.withValues(alpha: 0.25),
                  child: Text(
                    s.$1,
                    style: IsleText.caption(color: IsleColors.ocean900).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.$2,
                    style: compact
                        ? IsleText.caption(color: caption)
                        : IsleText.body(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 데이터 백업 화면 상단 — iCloud 미설정 시 강조
class SurvivalBackupGuideCard extends StatelessWidget {
  const SurvivalBackupGuideCard({
    super.key,
    this.onPickFolder,
    this.busy = false,
  });

  final VoidCallback? onPickFolder;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS || !IsleSurvivalBackupService.needsIcloudFolderPrompt()) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [IsleColors.ocean900, IsleColors.ocean700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_upload_outlined, color: IsleColors.gold500, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '안전장치 — iCloud 백업',
                  style: IsleText.subtitle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SurvivalBackupGuideSteps(compact: true, textColor: Colors.white),
          const SizedBox(height: 14),
          SizedBox(
            height: IsleSize.minTouchTarget,
            child: FilledButton.icon(
              onPressed: busy ? null : onPickFolder,
              style: FilledButton.styleFrom(
                backgroundColor: IsleColors.gold500,
                foregroundColor: IsleColors.ocean900,
              ),
              icon: const Icon(Icons.drive_folder_upload_outlined),
              label: const Text('지금 iCloud 폴더 선택'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 투어 직후·피드 1회 — 백업 폴더 안내 시트
Future<void> showSurvivalBackupGuideSheet(BuildContext context) async {
  if (!Platform.isIOS) return;
  if (IsleUserDefaults.survivalBackupGuideDismissed) return;
  if (!IsleSurvivalBackupService.needsIcloudFolderPrompt()) return;

  final action = await showIsleModalSheet<String>(
    context: context,
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('삭제해도 데이터 유지', style: IsleText.title(color: IsleColors.ocean900)),
            const SizedBox(height: 8),
            Text(
              IsleSurvivalBackupService.platformSurvivalHint,
              style: IsleText.caption(color: IsleColors.muted),
            ),
            const SizedBox(height: 16),
            const SurvivalBackupGuideSteps(),
            const SizedBox(height: 20),
            SizedBox(
              height: IsleSize.minTouchTarget,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, 'open'),
                child: const Text('데이터 백업으로 이동'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'later'),
              child: const Text('나중에'),
            ),
          ],
        ),
      );
    },
  );

  if (action == 'later') {
    await IsleUserDefaults.setSurvivalBackupGuideDismissed(true);
    await SetupJourneyService.markStepDone('icloud_backup');
    return;
  }
  if (action == 'open' && context.mounted) {
    await context.push('/settings/backup');
  }
}
