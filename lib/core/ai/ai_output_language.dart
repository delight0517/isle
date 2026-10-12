import '../localization/locale_controller.dart';

/// 앱 언어 설정 → 리포트/에세이 생성 프롬프트에 넣을 언어 이름
class AiOutputLanguage {
  AiOutputLanguage._();

  static const _names = {
    'ko': 'Korean',
    'en': 'English',
    'ja': 'Japanese',
    'zh': 'Chinese',
    'he': 'Hebrew',
  };

  static String get name => _names[AppLocaleController.savedCodeOrDefault] ?? 'Korean';
}
