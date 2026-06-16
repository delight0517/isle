import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/block_schedule/block_schedule_store.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/platform/platform_block_intent.dart';
import '../../../../core/youtube/youtube_timelock_service.dart';
import 'screen_time_guide_sheet.dart';

/// 타임락 — 앱 내 유튜브 + Safari·YouTube 앱 차단 안내
class YoutubeTimelockCard extends ConsumerStatefulWidget {
  const YoutubeTimelockCard({super.key});

  @override
  ConsumerState<YoutubeTimelockCard> createState() => _YoutubeTimelockCardState();
}

class _YoutubeTimelockCardState extends ConsumerState<YoutubeTimelockCard> {
  var _busy = false;

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    try {
      if (on) {
        await YoutubeTimelockService.enable();
        if (mounted && (Platform.isIOS || Platform.isAndroid)) {
          await showScreenTimeGuideSheet(context);
        }
      } else {
        await YoutubeTimelockService.disable();
      }
      await BlockScheduleStore.ensureOpen();
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = YoutubeTimelockService.isActive;

    return Card(
      color: on ? Colors.red.shade50 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phonelink_lock, color: on ? Colors.red.shade700 : IsleColors.ocean700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('YouTube 전체 차단 (타임락)', style: IsleText.subtitle()),
                ),
                if (_busy)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(value: on, onChanged: _toggle),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              on
                  ? 'Isle WebView 유튜브가 잠겼어요. ${PlatformBlockCopy.focusPanelExternalHint}'
                  : '켜면 24시간 스케줄 잠금이 적용되고, 외부 브라우저 차단 가이드가 열려요.',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            if ((Platform.isIOS || Platform.isAndroid) && on) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showScreenTimeGuideSheet(context),
                icon: const Icon(Icons.settings_suggest_outlined, size: 18),
                label: Text('${PlatformBlockCopy.externalBrowserName} · YouTube 앱 차단'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
