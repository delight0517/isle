import 'package:flutter/material.dart';

/// [GoRouter.navigatorKey] — 셸 밖 전체 화면 라우트용
final isleNavigatorKey = GlobalKey<NavigatorState>();

/// [StatefulShellRoute] 탭 분기 전용 — `/block/schedules` 등은 [isleNavigatorKey] 사용
final isleShellNavigatorKey = GlobalKey<NavigatorState>();
