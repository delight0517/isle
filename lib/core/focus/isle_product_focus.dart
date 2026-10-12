import '../services/isle_user_defaults.dart';

/// 3탭 홈 UI — (1) SNS (2) 나의 Isle (3) 시간관리 · 하단 네비
class IsleProductFocus {
  IsleProductFocus._();

  static bool get enabled => IsleUserDefaults.productFocusUi;

  static bool get showAdvanced => IsleUserDefaults.showAdvancedUi;

  /// SNS·섬·AI·브런치 탐색 등 2순위 UI
  static bool get hideSecondaryUi => enabled && !showAdvanced;
}
