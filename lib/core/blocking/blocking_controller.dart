import '../platform/screen_time_auth_status.dart';

export '../platform/screen_time_auth_status.dart';

/// # BlockingController — 플랫폼 중립 차단 엔진 인터페이스 (Bridge Protocol)
///
/// 목적: iOS(`ScreenTimeBridge` / FamilyControls·ManagedSettings)와 Android
/// (AccessibilityService + VpnService) 가 **동일한 추상 계약**을 구현하게 만들어,
/// 상위 로직(`FeedNotifier.build`, 차단 허브 UI, enforcement 서비스)이
/// `if (Platform.isIOS)` 분기 없이 한 인터페이스만 호출하도록 한다.
///
/// 장기 규칙(§ CLAUDE.md §6 [Bridge]): **새 차단 기능은 반드시 여기에 메서드를 추가하고
/// 양 플랫폼 구현(iOS/Android)을 모두 채운다.** 한쪽만 구현하면 다른 쪽은
/// 명시적으로 `unsupported`/no-op 를 반환해 "누락"이 컴파일·런타임에서 드러난다.
///
/// 구현체:
/// - [IosBlockingController]      — 기존 `IosScreenTimeService` 위임 래퍼 (행동 변화 0)
/// - [AndroidBlockingController]  — Accessibility/VPN 기반 (Phase 1~3에서 채움)
/// - [UnsupportedBlockingController] — 데스크톱/웹 등 미지원 플랫폼 no-op
abstract interface class BlockingController {
  /// UI 노출용 플랫폼 라벨 ('iOS Screen Time' · 'Android 접근성 차단' 등).
  String get platformLabel;

  /// 플랫폼별 차단 강제력·한계. UI 가 "잠금 보장 수준"을 정직하게 표기하는 데 사용.
  BlockingCapabilities get capabilities;

  /// 이 기기에서 차단 엔진을 쓸 수 있는가 (권한과 무관한 가용성).
  Future<bool> isAvailable();

  /// 현재 권한 상태.
  Future<ScreenTimeAuthStatus> authorizationStatus();

  /// 권한 요청 — 시스템 UI 후 실제 승인 여부와 실패 사유를 반환.
  Future<BlockingAuthResult> requestAuthorization();

  /// 승인 상태 단축 조회.
  Future<bool> isAuthorized();

  /// 차단할 앱 선택 UI 표시. null = 취소 또는 미지원.
  /// [existing] 기존 선택을 시드로, [additiveOnly] 면 기존 선택에서 추가만 허용.
  Future<BlockSelection?> pickTargets({
    BlockSelection? existing,
    bool additiveOnly = false,
  });

  /// 선택된 앱을 즉시 차단(쉴드 적용). 성공 여부 반환.
  Future<bool> applyAppShield(BlockSelection selection);

  /// 앱 쉴드 해제.
  Future<void> clearAppShield();

  /// 웹 도메인 차단 적용. 성공 여부 반환.
  /// iOS: Safari Content Blocker / 스케줄 web filter, Android: VpnService DNS 필터.
  Future<bool> applyWebBlock(List<String> domains);

  /// 웹 차단 해제.
  Future<void> clearWebBlock();

  /// 인앱 WebView 가 예전 OS 차단으로 막혔으면 해제 (iOS 한정 현상; 그 외 no-op).
  Future<void> ensureInAppWebViewUnblocked();

  /// 권한/시스템 차단 설정 화면 열기.
  Future<void> openSystemSettings();

  /// Android 배터리 최적화 예외 (iOS·기타 = true / no-op).
  Future<bool> isBatteryOptimizationIgnored();

  /// Android 배터리 최적화 해제 요청 화면.
  Future<void> openBatteryOptimizationSettings();

  /// 삼성·샤오미 등 제조사 배터리 화면 (실패 시 일반 배터리 설정).
  Future<void> openManufacturerBatterySettings();
}

/// 같은 "기능"이라도 OS 마다 보장 수준이 다르다 — UI 가 이를 정직하게 표기하기 위한 메타데이터.
enum BlockEnforcement {
  /// OS 가 강제, 사용자가 우회하기 어려움 (iOS FamilyControls/ManagedSettings).
  osEnforced,

  /// 앱이 포그라운드 감지·오버레이로 보조 — 사용자가 권한을 끄면 무력화 (Android Accessibility).
  bestEffort,

  /// 미지원.
  unsupported,
}

/// 플랫폼별 차단 능력·한계 요약.
class BlockingCapabilities {
  const BlockingCapabilities({
    required this.appBlock,
    required this.webBlock,
    required this.scheduleLock,
    required this.canPreventUninstall,
    this.note,
  });

  final BlockEnforcement appBlock;
  final BlockEnforcement webBlock;

  /// 스케줄 잠금(잠금 단계·쿨다운) 강제력.
  final BlockEnforcement scheduleLock;

  /// 앱 자체 삭제/비활성화를 막을 수 있는가 (iOS=불가지만 우회난이도↑, Android=Device Owner 없으면 불가).
  final bool canPreventUninstall;

  /// UI 에 노출 가능한 한국어 한계 설명.
  final String? note;
}

/// 권한 요청 결과 — iOS `ScreenTimeAuthResult` 의 플랫폼 중립 버전.
class BlockingAuthResult {
  const BlockingAuthResult({
    required this.ok,
    required this.status,
    this.code,
    this.message,
  });

  final bool ok;
  final ScreenTimeAuthStatus status;

  /// 실패 사유 분류 코드 (플랫폼별: ios=simulator|denied|..., android=usage_access|overlay|accessibility|...).
  final String? code;

  /// UI 에 그대로 노출 가능한 한국어 사유.
  final String? message;

  static const unsupported = BlockingAuthResult(
    ok: false,
    status: ScreenTimeAuthStatus.unavailable,
    code: 'platform_unsupported',
    message: '이 기기에서는 차단 기능을 쓸 수 없어요.',
  );
}

/// 차단 대상 선택 — 플랫폼이 의미를 해석하는 **불투명 페이로드**.
/// - iOS:     [encoded] = FamilyActivitySelection 인코딩 blob.
/// - Android: [encoded] = 패키지명 CSV (예: 'com.instagram.android,com.zhiliaoapp.musically').
class BlockSelection {
  const BlockSelection({
    required this.platform,
    required this.encoded,
    this.appCount = 0,
    this.categoryCount = 0,
  });

  /// 'ios' | 'android'
  final String platform;
  final String encoded;
  final int appCount;
  final int categoryCount;

  bool get isEmpty => encoded.isEmpty;
  bool get isNotEmpty => encoded.isNotEmpty;
  int get totalCount => appCount + categoryCount;
}
