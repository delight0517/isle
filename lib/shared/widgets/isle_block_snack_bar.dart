import 'package:flutter/material.dart';

import '../../core/explorer/explorer_site.dart';
import '../../features/home/presentation/widgets/schedule_block_detail_sheet.dart';

/// 차단 스낵바 — 탭·「자세히」→ 어떤 스케줄·규칙이 막는지 상세 시트
void showIsleBlockSnackBar(
  BuildContext context, {
  required String message,
  ExplorerSite? site,
  String? url,
  bool inAppExplorer = true,
}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final resolvedSite = site ?? _inferSite(url, message);

  void openDetail() {
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;
    showScheduleBlockDetailSheet(
      context,
      url: url,
      site: resolvedSite,
      previewMessage: message,
      inAppExplorer: inAppExplorer,
    );
  }

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      duration: const Duration(seconds: 7),
      content: InkWell(
        onTap: openDetail,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '탭 → 무엇이 막았는지 보기',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 6, top: 2),
                child: Icon(Icons.chevron_right, color: Colors.white70, size: 22),
              ),
            ],
          ),
        ),
      ),
      action: SnackBarAction(
        label: '자세히',
        textColor: Colors.amber.shade200,
        onPressed: openDetail,
      ),
    ),
  );
}

ExplorerSite? _inferSite(String? url, String message) {
  final blob = '$url $message'.toLowerCase();
  if (blob.contains('youtube') || blob.contains('youtu')) {
    return ExplorerSite.youtube;
  }
  if (blob.contains('instagram')) return ExplorerSite.instagram;
  if (blob.contains('brunch')) return ExplorerSite.brunch;
  if (blob.contains('safari') || blob.contains('브라우저')) {
    return ExplorerSite.custom;
  }
  return null;
}
