import 'platform_kind.dart';

/// 플랫폼별 UI 문구 **순수 함수** — 런타임은 [PlatformBlockCopy], 테스트는 여기 직접 호출.
///
/// 규칙:
/// - iOS 문구를 Android용으로, Android 문구를 iOS용으로 **통일 금지**.
/// - 양쪽이 같아도 OK인 문구만 공통 반환 (예: `안전 브라우저`).
/// - 새 사용자-facing OS 용어 → 여기에 분기 추가 후 [PlatformBlockCopy] 위임.
abstract final class PlatformCopyResolver {
  PlatformCopyResolver._();

  static String externalBrowserName(PlatformKind k) => switch (k) {
        PlatformKind.android => 'Chrome 등',
        PlatformKind.macOS => 'Safari·Chrome',
        PlatformKind.ios => 'Safari',
      };

  static String inAppBrowserLabel(PlatformKind k) => '안전 브라우저';

  /// 네비·퀵런처 라벨 — iOS는 Safari 브랜드 유지, Android는 중립.
  static String inAppBrowserNavLabel(PlatformKind k) => switch (k) {
        PlatformKind.android => '웹 브라우저',
        PlatformKind.ios || PlatformKind.macOS => 'Safari',
      };

  static String safeBrowserIntro(PlatformKind k) => switch (k) {
        PlatformKind.android =>
          'QR·링크·검색을 Chrome이 아닌 Isle 안에서 열어요.\n'
              '차단·SafeSearch·한도가 그대로 적용됩니다.',
        PlatformKind.ios || PlatformKind.macOS =>
          'QR·링크·검색을 Safari가 아닌 Isle 안에서 열어요.\n'
              '차단·SafeSearch·한도가 그대로 적용됩니다.',
      };

  static String qrScannerHint(PlatformKind k) => switch (k) {
        PlatformKind.android =>
          'QR을 프레임 안에 맞추면 Isle 안전 브라우저 또는 해당 앱으로 열어요.\n'
              'Chrome 등 외부 브라우저로 튕기지 않아요.',
        PlatformKind.ios || PlatformKind.macOS =>
          'QR을 프레임 안에 맞추면 Isle 안전 브라우저 또는 해당 앱으로 열어요.\n'
              'Safari로 튕기지 않아요.',
      };

  static String qrOpenSubtitle(PlatformKind k) => switch (k) {
        PlatformKind.android =>
          '카메라로 QR을 찍으면 Chrome이 아니라\n'
              'Isle 안전 브라우저에서 열어요',
        PlatformKind.ios || PlatformKind.macOS =>
          '카메라로 QR을 찍으면 Safari가 아니라\n'
              'Isle 안전 브라우저에서 열어요',
      };

  static String shareFromExternalAppTitle(PlatformKind k) => switch (k) {
        PlatformKind.android => '카카오톡·Chrome에서 보내기',
        PlatformKind.ios || PlatformKind.macOS => '카카오톡·Safari에서 보내기',
      };

  static String googleSearchFilterLabel(PlatformKind k) => switch (k) {
        PlatformKind.android => '구글 검색',
        PlatformKind.ios || PlatformKind.macOS => 'Safari(구글) 검색',
      };

  static String urlSheetTitle(PlatformKind k) => switch (k) {
        PlatformKind.android => '주소 열기',
        PlatformKind.ios || PlatformKind.macOS => 'Safari · 주소 열기',
      };

  static String urlSheetSubtitle(PlatformKind k) => switch (k) {
        PlatformKind.android => '앱 안 브라우저에서 열면 Isle 한도·타임락이 적용됩니다.',
        PlatformKind.ios || PlatformKind.macOS =>
          '인앱 Safari에서 YouTube를 보면 Isle 한도·타임락이 적용됩니다.',
      };

  static String urlSheetOpenButton(PlatformKind k) => switch (k) {
        PlatformKind.android => '브라우저에서 열기',
        PlatformKind.ios || PlatformKind.macOS => 'Safari에서 열기',
      };

  static String externalPasskeyBrowserName(PlatformKind k) => switch (k) {
        PlatformKind.android => 'Chrome',
        PlatformKind.ios || PlatformKind.macOS => 'Safari',
      };

  static String defaultBrowserTileSubtitle(PlatformKind k) => switch (k) {
        PlatformKind.android => 'QR·링크를 Isle로 — Android 설정 안내',
        PlatformKind.ios || PlatformKind.macOS => 'QR·링크를 Isle로 — iOS 설정 안내',
      };

  static String externalAppsSubtitle(PlatformKind k) => switch (k) {
        PlatformKind.android => '접근성 앱 차단 · 스케줄 연동',
        PlatformKind.ios || PlatformKind.macOS => 'Screen Time 앱 선택 · 스케줄 연동',
      };

  static String blockingCapabilitiesTitle(PlatformKind k) => switch (k) {
        PlatformKind.android => 'Android 차단 기능',
        PlatformKind.ios || PlatformKind.macOS => 'iPhone 제한 기능 안내',
      };

  static String blockFocusExternalAppsHint(PlatformKind k) => switch (k) {
        PlatformKind.android =>
          'Instagram·TikTok은 Isle 접근성 차단·디지털 웰빙으로 외부 앱을 막아요.',
        PlatformKind.macOS =>
          'Instagram·TikTok은 macOS Screen Time으로 앱 아이콘 자체를 잠급니다.',
        PlatformKind.ios =>
          'Instagram·TikTok은 Isle 안 브라우저가 아니라 '
              'iPhone의 앱 아이콘 자체를 Screen Time으로 잠급니다.',
      };

  static String systemYoutubeBlockGuideLabel(PlatformKind k) => switch (k) {
        PlatformKind.android => '유튜브 앱·Chrome (디지털 웰빙)',
        PlatformKind.ios || PlatformKind.macOS => '유튜브 앱·Safari (Screen Time)',
      };

  static String inAppBrowserMenuHint(PlatformKind k) => switch (k) {
        PlatformKind.android =>
          '안전 브라우저(⋮) → 「이 URL 차단」·「숨길 키워드」.',
        PlatformKind.ios || PlatformKind.macOS =>
          'Safari(⋮) → 「이 URL 차단」·「숨길 키워드」.',
      };

  static String blockedUrlMenuHint(PlatformKind k) => switch (k) {
        PlatformKind.android => '안전 브라우저(⋮) → 「이 URL 차단」으로 추가.',
        PlatformKind.ios || PlatformKind.macOS => 'Safari(⋮) → 「이 URL 차단」으로 추가.',
      };

  static String scheduleWebTargetChipLabel(PlatformKind k) => switch (k) {
        PlatformKind.android => '웹',
        PlatformKind.ios || PlatformKind.macOS => 'Safari·웹',
      };

  /// 스케줄 ③ — 기기에 설치된 네이티브 앱 (Screen Time / 접근성)
  static String nativeInstalledAppLabel(PlatformKind k) => switch (k) {
        PlatformKind.android => 'Android 앱',
        PlatformKind.ios || PlatformKind.macOS => 'iPhone 앱',
      };

  static String nativeInstalledAppPickHint(PlatformKind k) => switch (k) {
        PlatformKind.android =>
          '스케줄 편집 → ③ Android 앱에서 Instagram·TikTok 등을 고르면 '
              'Isle 밖에서도 앱이 막혀요.',
        PlatformKind.ios || PlatformKind.macOS =>
          '스케줄 편집 → ③ iPhone 앱에서 Instagram·TikTok 등을 고르면 '
              'Isle 밖에서도 OS 차단이 붙어요.',
      };

  static String appShieldPauseTitle(PlatformKind k) => switch (k) {
        PlatformKind.android => '앱 차단 잠깐 풀기',
        PlatformKind.ios || PlatformKind.macOS => 'Safari 잠깐 풀기',
      };

  static String appShieldPauseSubtitle(PlatformKind k) => switch (k) {
        PlatformKind.android =>
          '급하게 Chrome·Instagram 등을 써야 할 때 — 시간 후 자동 재잠금',
        PlatformKind.ios || PlatformKind.macOS =>
          'Safari 링크를 열어야 할 때 — 시간 후 자동으로 다시 잠겨요',
      };

  static String appShieldPausedBannerTitle(PlatformKind k) => switch (k) {
        PlatformKind.android => '앱 차단 해제 중',
        PlatformKind.ios || PlatformKind.macOS => 'Safari 차단 해제 중',
      };

  static String morningBlockQuickNote(PlatformKind k) => switch (k) {
        PlatformKind.android =>
          '아래 버튼을 누르면 차단 AI 챗에서 바로 설정해줘요.\n'
              '카카오톡·Chrome 등 앱 차단은 설정 후 「Android 앱 선택」이 필요해요.',
        PlatformKind.ios || PlatformKind.macOS =>
          '아래 버튼을 누르면 차단 AI 챗에서 바로 설정해줘요.\n'
              '카카오톡 앱 차단은 설정 후 Screen Time에서 앱 선택이 필요해요.',
      };

  static String isleInAppUsageFootnote(PlatformKind k) => switch (k) {
        PlatformKind.android =>
          '앱 아이콘(Instagram 등) 전체 사용량은 디지털 웰빙에서 확인해요. '
              '아래는 Isle에서 본 시간입니다.',
        PlatformKind.ios || PlatformKind.macOS =>
          '앱 아이콘(Instagram 등) 전체 사용량은 iOS 스크린 타임에서 확인해요. '
              '아래는 Isle에서 본 시간입니다.',
      };

  static String kakaoWebBlockButtonLabel(PlatformKind k) => switch (k) {
        PlatformKind.android => 'Chrome kakao.com',
        PlatformKind.ios || PlatformKind.macOS => 'Safari kakao.com',
      };
}
