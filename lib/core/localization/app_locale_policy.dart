import 'package:flutter/material.dart';

/// One policy for saved preferences and every native translation catalogue.
class AppLocalePolicy {
  AppLocalePolicy._();

  static const defaultCode = 'ko';
  static const languageOptions = <String, String>{
    'ko': '한국어',
    'en': 'English',
    'ja': '日本語',
    'zh': '中文',
    'he': 'עברית',
  };
  static const supportedLocales = <Locale>[
    Locale('ko'),
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
    Locale('he'),
  ];

  static String normalize(String? code) {
    var lang = (code ?? '').trim().toLowerCase().split(RegExp('[-_]')).first;
    if (lang == 'iw') lang = 'he';
    return languageOptions.containsKey(lang) ? lang : defaultCode;
  }

  static String translate(
      Map<String, Map<String, String>> catalogues, String? code, String key,
      {Map<String, String>? args}) {
    final lang = normalize(code);
    var value = catalogues[lang]?[key] ?? catalogues[defaultCode]?[key] ?? key;
    args?.forEach((name, text) => value = value.replaceAll('{$name}', text));
    return value;
  }
}
