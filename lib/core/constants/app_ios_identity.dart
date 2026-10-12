/// iOS 앱 식별자 — Isle·Isle Dev·모아가 서로 덮어쓰지 않도록 분리.
///
/// | 앱 | Bundle ID | App Group |
/// |----|-----------|-----------|
/// | Isle (프로덕션) | `com.isle.app.isle` | `group.com.isle.app` |
/// | Isle Dev (레거시) | `com.isle.app.isle.dev` | `group.com.isle.app` |
/// | **모아 (이 리포)** | [bundleId] | [appGroupId] |
class AppIosIdentity {
  AppIosIdentity._();

  static const bundleId = 'com.isle.app.moa.dev';
  static const appGroupId = 'group.com.isle.app.moa';
  static const displayName = '모아';
  static const urlScheme = 'moa';
  static const scheduleSyncTaskId = 'com.isle.app.moa.scheduleSync';
}
