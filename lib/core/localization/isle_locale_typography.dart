import 'package:flutter/material.dart';

/// Locale-aware UI fonts (system + Noto fallbacks in [ThemeData.fontFamilyFallback]).
class IsleLocaleTypography {
  IsleLocaleTypography._();

  /// 시스템 폰트 우선 — Google Fonts 번들/네트워크 없이 한·일·중 표시
  static String? fontFamilyFor(String languageCode) => switch (languageCode) {
        'ja' => null,
        'zh' => null,
        'he' => null,
        'ko' => null,
        _ => null,
      };

  static TextDirection textDirectionFor(String languageCode) =>
      languageCode == 'he' ? TextDirection.rtl : TextDirection.ltr;

  static ThemeData applyToTheme(ThemeData base, Locale? locale) {
    final code = locale?.languageCode ?? 'ko';
    final family = fontFamilyFor(code);
    if (family == null) return base;
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: family),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
    );
  }
}
