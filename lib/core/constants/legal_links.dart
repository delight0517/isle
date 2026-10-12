/// Play Console · 개인정보처리방침 · 지원 연락처 단일 출처.
/// 출시 전 [privacyPolicyUrl]·[supportEmail]을 실제 값으로 바꾸세요.
class LegalLinks {
  LegalLinks._();

  /// HTTPS 공개 URL (Play Console 필수)
  static const privacyPolicyUrl = 'https://yourdomain.com/privacy';

  /// 스토어·앱 내 문의 (Play Console 필수)
  static const supportEmail = 'support@yourdomain.com';

  static bool get hasPrivacyPolicyUrl =>
      privacyPolicyUrl.startsWith('https://') && !privacyPolicyUrl.contains('yourdomain');

  static bool get hasSupportEmail =>
      supportEmail.contains('@') && !supportEmail.contains('yourdomain');

  static Uri? get privacyPolicyUri =>
      hasPrivacyPolicyUrl ? Uri.parse(privacyPolicyUrl) : null;

  static Uri get accountDeletionMailto => Uri(
        scheme: 'mailto',
        path: hasSupportEmail ? supportEmail : 'support@example.com',
        queryParameters: const {
          'subject': 'Isle 계정·데이터 삭제 요청',
        },
      );
}
