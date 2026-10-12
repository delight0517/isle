import 'package:flutter/material.dart';

import '../../../../core/block_schedule/schedule_target_access_guard.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/navigation/schedule_overlay_navigation.dart';
import '../../../../core/qa/device_qa_item_panel.dart';
import '../../../../core/youtube/youtube_access_guard.dart';
import '../../../../core/youtube/youtube_timelock_service.dart';
import 'isle_youtube_schedule_sheet.dart';

/// `/youtube/browser?qa=1` — v245 잠금 오버레이·편집 네비 실기기 확인
class YoutubeBrowserQaHost extends StatefulWidget {
  const YoutubeBrowserQaHost({super.key, required this.child});

  final Widget child;

  @override
  State<YoutubeBrowserQaHost> createState() => _YoutubeBrowserQaHostState();
}

class _YoutubeBrowserQaHostState extends State<YoutubeBrowserQaHost> {
  bool _overlayConfirmed = false;
  bool _editVisited = false;

  bool get _scheduleLocked =>
      YoutubeAccessGuard.activeLock() == YoutubeLockReason.schedule ||
      ScheduleTargetAccessGuard.isIsleYoutubeBlocked;

  Future<void> _openScheduleEdit() async {
    final id = YoutubeTimelockService.isActive
        ? YoutubeTimelockService.timelockScheduleId
        : null;
    openBlockScheduleFromOverlay(context, scheduleId: id);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _editVisited = true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            8,
            MediaQuery.paddingOf(context).top + 4,
            8,
            0,
          ),
          child: DeviceQaItemPanel(
            itemId: 'youtube_lock_overlay',
            title: '실기기 확인 — YouTube 잠금',
            compact: true,
            steps: [
              DeviceQaStep(
                label: '① 스케줄·Isle 유튜브 잠금 ON',
                done: _scheduleLocked,
              ),
              DeviceQaStep(
                label: '② 오버레이 1개·상단 칩「스케줄」',
                done: _overlayConfirmed,
              ),
              DeviceQaStep(
                label: '③ 「이 스케줄 편집」 흰 화면 없음',
                done: _editVisited,
              ),
            ],
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => showIsleYoutubeScheduleSheet(context),
                    child: const Text('스케줄 켜기'),
                  ),
                  OutlinedButton(
                    onPressed: _scheduleLocked
                        ? () => setState(() => _overlayConfirmed = true)
                        : null,
                    child: const Text('오버레이 확인'),
                  ),
                  OutlinedButton(
                    onPressed: _openScheduleEdit,
                    child: const Text('편집 화면 테스트'),
                  ),
                ],
              ),
              if (!_scheduleLocked)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '먼저 스케줄을 켠 뒤 YouTube가 잠기는지 확인하세요',
                    style: IsleText.caption(color: IsleColors.muted),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
