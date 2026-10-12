import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/block_schedule/schedule_block_user_message.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/explorer/explorer_site.dart';
import '../../../../core/navigation/isle_navigation.dart';
import '../../../../features/home/presentation/widgets/schedule_block_detail_sheet.dart';

/// WebView 없이 — 차단 이유만 전면 표시 (스켈레톤 무한 로딩 방지)
class ExplorerEntryBlockedScreen extends StatelessWidget {
  const ExplorerEntryBlockedScreen({
    super.key,
    required this.site,
    this.url,
    this.legacyMessage,
  });

  final ExplorerSite site;
  final String? url;
  final String? legacyMessage;

  @override
  Widget build(BuildContext context) {
    final copy = ScheduleBlockUserMessage.entryCopy(
      site: site,
      url: url,
      legacyMessage: legacyMessage,
      inAppExplorer: true,
    );
    final isLimit = copy.isYoutubeDailyLimit;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(IsleSize.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                isLimit ? Icons.hourglass_disabled : Icons.lock_outline,
                size: 56,
                color: isLimit ? Colors.red.shade300 : Colors.white70,
              ),
              const SizedBox(height: 20),
              Text(
                copy.title,
                style: IsleText.title(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                copy.body,
                style:
                    IsleText.body(color: Colors.white70).copyWith(height: 1.45),
                textAlign: TextAlign.center,
              ),
              if (copy.usageChip != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Chip(
                    label: Text(copy.usageChip!, style: IsleText.caption()),
                    backgroundColor: Colors.red.shade900.withValues(alpha: 0.5),
                  ),
                ),
              ],
              const Spacer(),
              if (copy.primaryRoute != null)
                FilledButton(
                  onPressed: () => _replaceWithPrimaryRoute(
                    context,
                    copy.primaryRoute!,
                  ),
                  child: Text(copy.primaryButtonLabel ?? '설정 열기'),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                onPressed: () => showScheduleBlockDetailSheet(
                  context,
                  site: site,
                  url: url,
                  previewMessage: copy.oneLine,
                  inAppExplorer: true,
                ),
                child: const Text('차단 이유 전체 보기'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child:
                    Text('돌아가기', style: IsleText.body(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _replaceWithPrimaryRoute(BuildContext context, String route) {
    final opened = IsleNavigation.pushReplacement(route, from: context);
    if (opened) return;
    if (context.mounted) context.go(route);
  }
}
