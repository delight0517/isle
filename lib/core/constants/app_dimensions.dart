import 'package:flutter/material.dart';

class IsleSize {
  IsleSize._();
  static const double screenPadding = 16.0;
  static const double cardRadius = 16.0;
  static const double chipRadius = 100.0;
  static const double sheetRadius = 24.0;
  static const double cardGap = 8.0;
  static const double innerPadding = 12.0;
  static const double bottomNavH = 72.0;
  static const double thumbnailH = 200.0;
  static const double avatarSm = 28.0;
  /// iOS HIG 최소 터치 영역 [Vantage]
  static const double minTouchTarget = 44.0;
  static const double avatarMd = 44.0;
  static const double avatarLg = 80.0;

  /// [AppVersionBadge] + FAB 여유 — ListView 하단 패딩
  static const double versionBadgeClearance = 140.0;

  static double scrollBottomPadding(BuildContext context, {double extra = 16}) {
    return MediaQuery.paddingOf(context).bottom + versionBadgeClearance + extra;
  }
}
