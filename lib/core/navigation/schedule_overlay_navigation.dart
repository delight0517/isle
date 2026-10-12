import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'isle_navigation.dart';
import 'isle_routes.dart';
import '../services/isle_app_log_service.dart';

/// `/block/*` — StatefulShell 밖 전용. `context.push`만 쓰면 검은 화면.
bool _pushOutsideShell(BuildContext context, String location) =>
    IsleNavigation.push(location, from: context);

bool _replaceOutsideShell(BuildContext context, String location) =>
    IsleNavigation.pushReplacement(location, from: context);

/// 셸 밖 스케줄 목록
bool pushBlockScheduleList(BuildContext context) =>
    _pushOutsideShell(context, IsleRoutes.blockSchedulesOutsideShell);

/// 셸 밖 스케줄 편집
bool pushBlockScheduleEdit(BuildContext context, String scheduleId) =>
    _pushOutsideShell(
      context,
      IsleRoutes.blockScheduleEditOutsideShell(scheduleId),
    );

/// WebView·오버레이(셸 밖)에서 스케줄 화면으로
void openBlockScheduleFromOverlay(BuildContext context, {String? scheduleId}) {
  final location = scheduleId != null
      ? IsleRoutes.blockScheduleEditOutsideShell(scheduleId)
      : IsleRoutes.blockSchedulesOutsideShell;
  IsleAppLogService.log('openBlockScheduleFromOverlay: replace → $location');
  if (_replaceOutsideShell(context, location)) return;
  IsleAppLogService.log(
    'openBlockScheduleFromOverlay: replace failed → $location',
    level: IsleLogLevel.warn,
  );
  IsleNavigation.go('/home/my-isle', from: context);
}

/// [BlockSchedulesScreen] — 목록 경로에 맞는 편집 push
void pushScheduleEditFromList(BuildContext context, String scheduleId) {
  final matched = GoRouterState.of(context).matchedLocation;
  if (matched.startsWith('/settings/block-schedules')) {
    context.push(scheduleId);
    return;
  }
  pushBlockScheduleEdit(context, scheduleId);
}

/// `/block/*` 외 경로 — 설정 탭 안이면 [context.push] 폴백
bool pushRoutePreferRoot(BuildContext context, String location) {
  if (location.startsWith('/block/')) {
    return _pushOutsideShell(context, location);
  }
  if (IsleNavigation.push(location, from: context)) return true;
  if (context.mounted) {
    context.push(location);
    return true;
  }
  return false;
}

/// 시트 닫힌 뒤 스케줄 편집 (레이아웃 레이스 → 검은 화면 방지)
Future<void> popSheetThenPushScheduleEdit(
  BuildContext sheetContext,
  BuildContext hostContext,
  String scheduleId,
) async {
  final nav = Navigator.maybeOf(sheetContext, rootNavigator: true);
  if (nav != null && nav.canPop()) {
    nav.pop();
  }
  await Future<void>.delayed(const Duration(milliseconds: 320));
  if (!hostContext.mounted) return;
  pushBlockScheduleEdit(hostContext, scheduleId);
}

/// 시트 닫힌 뒤 스케줄 목록
Future<void> popSheetThenPushScheduleList(
  BuildContext sheetContext,
  BuildContext hostContext,
) async {
  final nav = Navigator.maybeOf(sheetContext, rootNavigator: true);
  if (nav != null && nav.canPop()) {
    nav.pop();
  }
  await Future<void>.delayed(const Duration(milliseconds: 320));
  if (!hostContext.mounted) return;
  pushBlockScheduleList(hostContext);
}
