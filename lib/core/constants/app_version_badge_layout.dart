import 'package:flutter/foundation.dart';

/// 하단 sticky 저장 바 등이 있을 때 [AppVersionBadge]를 위로 올림
class AppVersionBadgeLayout extends ChangeNotifier {
  AppVersionBadgeLayout._();
  static final AppVersionBadgeLayout instance = AppVersionBadgeLayout._();

  double _extraBottomLift = 0;

  double get extraBottomLift => _extraBottomLift;

  void setLift(double pixels) {
    final v = pixels < 0 ? 0.0 : pixels;
    if (_extraBottomLift == v) return;
    _extraBottomLift = v;
    notifyListeners();
  }

  void clearLift() => setLift(0);
}
