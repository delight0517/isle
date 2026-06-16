class Env {
  Env._();
  // TODO: 실제 프로젝트 생성 후 값 입력
  static const supabaseUrl = 'YOUR_SUPABASE_URL';
  static const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  /// OpenAI 호환 API (요약 카드). 비우면 로컬 폴백 문구 사용.
  static const openAiApiKey = '';
  static const openAiBaseUrl = 'https://api.openai.com/v1';
  static const openAiModel = 'gpt-4o-mini';

  /// 플레이스홀더일 때는 Supabase 미초기화(로컬 UI·더미 데이터만).
  static bool get isSupabaseConfigured =>
      supabaseUrl.startsWith('https://') && !supabaseAnonKey.contains('YOUR');

  /// env.dart 키 또는 설정 화면에 저장한 키
  static bool get isAiConfigured =>
      openAiApiKey.isNotEmpty && !openAiApiKey.contains('YOUR');

  /// Google Cloud iOS OAuth 클라이언트 ID (xxx.apps.googleusercontent.com)
  /// → Info.plist `CFBundleURLSchemes`에 `com.googleusercontent.apps.{숫자부분}` 추가 필요
  static const googleIosClientId = '';

  /// Android OAuth 클라이언트 ID (선택 — 네이티브 Google 로그인)
  static const googleAndroidClientId = '';

  /// Supabase Google용 Web 클라이언트 ID (Android serverClientId)
  static const googleWebClientId = '';

  static bool get isGoogleSignInConfigured {
    if (googleWebClientId.isNotEmpty && !googleWebClientId.contains('YOUR')) {
      return true;
    }
    if (googleIosClientId.isNotEmpty && !googleIosClientId.contains('YOUR')) {
      return true;
    }
    return googleAndroidClientId.isNotEmpty && !googleAndroidClientId.contains('YOUR');
  }
}
