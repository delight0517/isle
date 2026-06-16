import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/block_schedule/block_schedule_enforcement_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/platform/isle_apple_platform.dart';
import '../../../../core/platform/ios_screen_time_service.dart';
import '../../../../shared/widgets/isle_sheet.dart';
import 'android_system_block_sheet.dart';

/// 외부 브라우저·시스템 앱 YouTube — iOS: Screen Time / Android: Wellbeing
Future<void> showScreenTimeGuideSheet(BuildContext context) async {
  if (Platform.isAndroid) {
    await showAndroidSystemBlockSheet(context);
    return;
  }
  if (!IsleApplePlatform.isScreenTimeHost) return;

  final authorized = await IosScreenTimeService.isAuthorized();

  if (!context.mounted) return;
  await showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('다른 앱·Safari의 YouTube', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          Text(
            'Isle WebView는 「YouTube 전체 차단(타임락)」으로 막을 수 있어요.\n'
            'YouTube 앱·Safari는 Apple Screen Time에서 한 번 더 설정해야 합니다 (아래 단계).',
            style: IsleText.body(color: IsleColors.muted),
          ),
          const SizedBox(height: 16),
          _Step(n: '1', text: '설정 → 스크린 타임 → 앱 및 웹사이트 제한 (또는 콘텐츠 제한)'),
          _Step(n: '2', text: 'YouTube 앱·Safari·youtube.com 을 허용 또는 차단'),
          _Step(n: '3', text: '잠금 해제 시: 같은 화면에서 제한을 끄거나 허용 목록에 추가'),
          if (!authorized) ...[
            const SizedBox(height: 12),
            Text(
              '먼저 Isle에서 Screen Time 권한을 허용하면, 이후 Apple이 도메인 선택 UI를 띄울 수 있습니다.',
              style: IsleText.caption(color: IsleColors.ocean700),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await IosScreenTimeService.openScreenTimeSettings();
            },
            icon: const Icon(Icons.open_in_new),
            label: Text(Platform.isMacOS ? 'macOS Screen Time 열기' : 'iOS 설정 열기'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await IosScreenTimeService.requestAuthorizationDetailed();
              final ok = result.ok;
              if (ctx.mounted) {
                if (!ok) {
                  final traceCode = IosScreenTimeService.buildSupportCode(
                    phase: 'GUIDE',
                    detail: result.code ?? result.status.name,
                  );
                  final copyText = IosScreenTimeService.buildSupportCopyText(
                    traceCode: traceCode,
                    result: result,
                  );
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('권한 요청 실패 (${result.message ?? '다시 시도해 주세요'})\n오류 코드: $traceCode'),
                      duration: const Duration(seconds: 6),
                      action: SnackBarAction(
                        label: '복사',
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: copyText));
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('오류 로그를 복사했어요')),
                          );
                        },
                      ),
                    ),
                  );
                }
                if (ok) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('권한 허용됨 — 이제 설정에서 YouTube를 선택하세요')),
                  );
                }
              }
              await BlockScheduleEnforcementService.syncPlatformEnforcement();
            },
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Isle Screen Time 권한 요청'),
          ),
        ],
      ),
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: IsleColors.ocean500,
            child: Text(n, style: IsleText.badge(color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: IsleText.body())),
        ],
      ),
    );
  }
}
