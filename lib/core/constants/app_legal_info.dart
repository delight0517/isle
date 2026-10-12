/// Play Console · 개인정보처리방침 · 문의 — 단일 출처.
class AppLegalInfo {
  AppLegalInfo._();

  static const appName = 'Isle';

  /// Play Console 필수 — `docs/legal/privacy_policy.html` 배포 후 동일 URL 유지.
  static const privacyPolicyUrl =
      'https://rogan2534.github.io/isle-legal/privacy_policy.html';

  static const supportEmail = 'rogan2534@gmail.com';

  static Uri get privacyPolicyUri => Uri.parse(privacyPolicyUrl);

  static Uri get accountDeletionMailto => Uri(
        scheme: 'mailto',
        path: supportEmail,
        query: _encodeQuery({
          'subject': 'Isle 계정·데이터 삭제 요청',
          'body': '삭제를 원하는 계정 이메일:\n\n',
        }),
      );

  static String _encodeQuery(Map<String, String> params) => params.entries
      .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');

  static const thirdPartyDisclaimer =
      'Isle는 YouTube, Instagram, Google의 공식 앱이 아니며 제휴 관계가 없습니다.';

  static const selfManagementNotice =
      'Isle는 본인의 콘텐츠·시간 사용을 스스로 관리하는 도구입니다. '
      '타인을 감시하거나 원격으로 통제하는 앱이 아닙니다. '
      '차단 기능은 기기·설정에 따라 달라지며, 완전 차단을 보장하지 않습니다.';

  static const accessibilityPermissionNotice =
      '차단 목록에 넣은 앱이 열릴 때 알려 주기 위해 접근성이 필요합니다. '
      '화면 내용을 읽거나 서버로 보내지 않습니다.';

  static const vpnPermissionNotice =
      '선택한 웹사이트 도메인을 기기 안에서만 차단합니다. '
      '인터넷 트래픽을 Isle 서버로 보내지 않습니다.';

  static const usageStatsPermissionNotice =
      '설정한 일일 앱 사용 한도를 확인하기 위해 필요합니다. '
      '다른 앱 이름과 사용 시간만 기기에서 계산하며, 서버로 전송하지 않습니다.';

  static const apiKeyNotice =
      'API 키는 사용자가 직접 입력한 경우에만 기기에 암호화 저장됩니다. '
      'AI 요청 시 사용자가 선택한 API 제공자에게 전송됩니다.';

  static const sessionCookieNotice =
      '제3자 플랫폼 계정 [REDACTED] 않으며, 로그인 세션 쿠키만 기기에 암호화 저장합니다.';
}
