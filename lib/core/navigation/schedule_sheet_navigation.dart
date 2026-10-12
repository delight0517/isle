import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/isle_app_log_service.dart';
import 'isle_navigation.dart';
import 'isle_routes.dart';

bool _dismissPushInFlight = false;

/// 모달 시트를 닫은 뒤 push — 연속 시트·라우트 레이스 방지
Future<void> dismissSheetThenPush(
  BuildContext sheetContext,
  BuildContext hostContext,
  String location,
) async {
  if (_dismissPushInFlight) {
    IsleAppLogService.log(
      'dismissSheetThenPush: skipped (in flight) → $location',
      level: IsleLogLevel.debug,
    );
    return;
  }
  _dismissPushInFlight = true;
  try {
    IsleAppLogService.log('dismissSheetThenPush: start → $location');
    // 탭 핸들러 안에서 동기 pop() 하면 Navigator !_debugLocked 발생
    await Future<void>.delayed(Duration.zero);
    if (sheetContext.mounted) {
      final nav = Navigator.maybeOf(sheetContext, rootNavigator: true);
      if (nav != null && nav.canPop()) {
        nav.pop();
      }
    }
    // 시트 닫힘(모달) 애니메이션이 끝난 뒤 push — 곧바로 push하면 새 라우트가
    // 레이아웃되지 못해(RenderIgnorePointer NEEDS-LAYOUT) 검은 화면이 됨.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (IsleNavigation.push(location)) {
      IsleAppLogService.log('dismissSheetThenPush: pushed via root key');
      return;
    }
    // 폴백: host 컨텍스트의 라우터
    if (hostContext.mounted) {
      final router = GoRouter.maybeOf(hostContext);
      if (router != null) {
        IsleAppLogService.log(
            'dismissSheetThenPush: fallback host router push');
        await hostContext.push(location);
        return;
      }
    }
    IsleAppLogService.log(
      'dismissSheetThenPush: push FAILED for $location',
      level: IsleLogLevel.warn,
    );
    if (hostContext.mounted) {
      ScaffoldMessenger.of(hostContext).showSnackBar(
        SnackBar(
            content: Text('${IsleRoutes.blockSchedulesOutsideShell}에서 열어 주세요')),
      );
    }
  } finally {
    _dismissPushInFlight = false;
  }
}

/// 모달 시트를 닫은 뒤 다른 시트 표시
Future<void> dismissSheetThenShow(
  BuildContext sheetContext,
  BuildContext hostContext,
  Future<void> Function(BuildContext host) showNext,
) async {
  if (_dismissPushInFlight) return;
  _dismissPushInFlight = true;
  try {
    await Future<void>.delayed(Duration.zero);
    if (sheetContext.mounted) {
      final nav = Navigator.maybeOf(sheetContext, rootNavigator: true);
      if (nav != null && nav.canPop()) {
        nav.pop();
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!hostContext.mounted) return;
    await showNext(hostContext);
  } finally {
    _dismissPushInFlight = false;
  }
}
