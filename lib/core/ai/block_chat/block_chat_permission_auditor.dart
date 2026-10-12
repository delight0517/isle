import 'dart:io' show Platform;

import '../../blocking/blocking_controller_provider.dart';
import '../../intervention/schedule_screen_time_store.dart';
import '../../platform/ios_extension_status.dart';
import '../../platform/ios_screen_time_service.dart';
import '../../platform/isle_apple_platform.dart';
import '../../navigation/isle_routes.dart';
import 'block_chat_models.dart';

/// AI 챗으로 스케줄·차단 저장 후 — OS 권한·앱 선택 누락 감지
class BlockChatPermissionAuditor {
  BlockChatPermissionAuditor._();

  static Future<List<BlockChatPermissionGap>> audit({
    String? scheduleId,
    required bool needsOsAppBlock,
    bool needsSafariContentBlocker = false,
  }) async {
    final gaps = <BlockChatPermissionGap>[];

    // 도메인/URL/채널 차단(성인 사이트 팩 포함)은 Screen Time 앱 쉴드와
    // 무관하게 Safari Content Blocker 확장이 켜져 있어야만 실제로 막힌다 —
    // 목록엔 저장되지만 확장이 꺼져 있으면 조용히 아무것도 안 막히는 실사용
    // 버그였다. iOS에서만 의미 있는 확장이라 Android는 건너뛴다.
    if (needsSafariContentBlocker && Platform.isIOS) {
      final status = await IosExtensionStatus.load();
      if (!status.safariContentBlocker) {
        gaps.add(
          const BlockChatPermissionGap(
            kind: BlockChatPermissionGapKind.osAuth,
            title: 'Safari 차단 확장 꺼짐',
            issue: '도메인·사이트는 목록에 저장됐지만, Safari 설정에서 '
                '「Isle 콘텐츠 차단」 확장을 켜지 않으면 Safari에서 실제로는 '
                '전혀 막히지 않아요. (Chrome 등 다른 브라우저는 iOS 제약상 '
                '애초에 도메인 차단이 불가능해요 — Safari에서만 작동해요.)',
            effectWhenGranted: '설정 → Safari → 확장에서 켜면, 저장된 도메인이 '
                'Safari 안에서 바로 막혀요.',
            route: '/settings/iphone-blocking',
            routeLabel: 'Safari 확장 켜는 법',
            actionLabel: '지금 확인',
          ),
        );
      }
    }

    if (!needsOsAppBlock) return gaps;

    if (!IsleApplePlatform.isNativeBlockHost) {
      gaps.add(
        const BlockChatPermissionGap(
          kind: BlockChatPermissionGapKind.unsupported,
          title: '이 기기는 OS 앱 차단 미지원',
          issue:
              '스케줄·Isle 안 차단은 저장됐지만, iPhone/Android 앱 자체를 막는 기능은 이 기기에서 쓸 수 없어요.',
          effectWhenGranted: '',
          route: '/home/block',
          routeLabel: '차단 탭',
        ),
      );
      return gaps;
    }

    if (Platform.isAndroid) {
      final c = resolveBlockingController();
      if (!await c.isAvailable()) {
        gaps.add(
          const BlockChatPermissionGap(
            kind: BlockChatPermissionGapKind.osUnavailable,
            title: 'Android 차단 엔진 사용 불가',
            issue: '스케줄은 저장됐지만, 이 빌드에서 앱 차단을 켤 수 없어요.',
            effectWhenGranted: '지원 빌드에서는 접근성 허용 후 선택한 앱이 열릴 때 Isle이 막아 줘요.',
            route: '/settings/android-system-block',
            routeLabel: 'Android 차단 설정',
          ),
        );
        return gaps;
      }
      if (!await c.isAuthorized()) {
        gaps.add(
          const BlockChatPermissionGap(
            kind: BlockChatPermissionGapKind.osAuth,
            title: '접근성 차단 허용 필요',
            issue:
                '스케줄은 켜졌지만, Android가 다른 앱을 막으려면 「접근성」에서 Isle 차단을 허용해야 해요.',
            effectWhenGranted:
                '허용하면 스케줄 시간에 Instagram·YouTube 등 선택한 앱을 열 때 '
                '전면 안내가 뜨고, 의도한 대로 시간을 지킬 수 있어요.',
            route: '/settings/android-system-block',
            routeLabel: '지금 허용하기',
            actionLabel: '접근성 켜기',
          ),
        );
      }
    } else if (IsleApplePlatform.isScreenTimeHost) {
      if (!await IosScreenTimeService.isAvailable()) {
        gaps.add(
          const BlockChatPermissionGap(
            kind: BlockChatPermissionGapKind.osUnavailable,
            title: 'Screen Time 미지원 빌드',
            issue: '스케줄은 저장됐지만, 이 빌드는 iOS Screen Time 연동이 없어요.',
            effectWhenGranted: '개발 빌드에서는 Family Controls 권한 후 Safari·앱이 OS에서 잠겨요.',
            route: '/settings/iphone-blocking',
            routeLabel: 'iPhone 차단 안내',
          ),
        );
        return gaps;
      }
      if (!await IosScreenTimeService.isAuthorized()) {
        gaps.add(
          const BlockChatPermissionGap(
            kind: BlockChatPermissionGapKind.osAuth,
            title: 'Screen Time 권한 필요',
            issue:
                '스케줄은 저장됐지만, iPhone이 Safari·Instagram 등을 막으려면 '
                '「스크린 타임」 권한 허용이 필요해요.',
            effectWhenGranted:
                '허용 후 스케줄에 고른 앱은 슬롯 시간에 홈 화면에서 열리지 않고, '
                'Isle 안 차단과 함께 이중으로 지켜져요.',
            route: '/settings/iphone-blocking',
            routeLabel: '권한 안내',
            actionLabel: '지금 허용',
          ),
        );
      }
    }

    if (scheduleId != null && scheduleId.isNotEmpty) {
      await ScheduleScreenTimeStore.ensureOpen();
      final apps = ScheduleScreenTimeStore.appCountFor(scheduleId);
      final cats = ScheduleScreenTimeStore.categoryCountFor(scheduleId);
      if (apps == 0 && cats == 0) {
        final editRoute = IsleRoutes.blockScheduleEditOutsideShell(scheduleId);
        gaps.add(
          BlockChatPermissionGap(
            kind: BlockChatPermissionGapKind.scheduleAppPick,
            title: Platform.isIOS ? '막을 iPhone 앱 선택' : '막을 앱 선택',
            issue: Platform.isIOS
                ? '스케줄 시간은 잡혔지만, Safari·YouTube·Instagram 앱 아이콘은 '
                    '아직 Screen Time으로 고르지 않았어요.'
                : '스케줄은 켜졌지만, 차단할 앱 목록이 비어 있어요.',
            effectWhenGranted: Platform.isIOS
                ? '스케줄 편집 ③에서 앱을 고르면, 슬롯 안에 그 앱을 탭했을 때 '
                    'iOS가 바로 막고 — QR·링크로 우회하기 어려워져요.'
                : '앱을 고르면 스케줄 시간에 해당 앱을 열 때 Isle이 전면으로 막아 줘요.',
            route: editRoute,
            routeLabel: '스케줄 편집 ③',
            actionLabel: Platform.isIOS ? '앱 고르기' : '앱 선택',
          ),
        );
      }
    }

    return gaps;
  }
}
