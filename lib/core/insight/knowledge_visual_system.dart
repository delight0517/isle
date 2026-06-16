import 'package:flutter/material.dart';

/// Living Knowledge Identity — 에디토리얼·모노크롬 디자인 토큰
/// (오프라인: Google Fonts 미사용 — 시스템 폰트, 한글 SF/Roboto)
class KnowledgeVisual {
  KnowledgeVisual._();

  static const slogan = 'What you consume is who you are';

  // Monochrome canvas
  static const ink = Color(0xFF0A0A0A);
  static const onInk = Color(0xFFFFFFFF);
  static const paper = Color(0xFFFAFAFA);
  static const surface = Color(0xFFFFFFFF);
  static const hairline = Color(0xFFE8E8E8);
  static const caption = Color(0xFF737373);

  // Accent — AI·데이터·키워드 전용
  static const intelligentBlue = Color(0xFF1D4ED8);
  static const intelligentBlueSoft = Color(0xFFEFF6FF);
  static const intelligentBlueMuted = Color(0xFF93C5FD);

  static Color canvas(Brightness brightness) =>
      brightness == Brightness.dark ? ink : paper;

  static Color foreground(Brightness brightness) =>
      brightness == Brightness.dark ? onInk : ink;

  static Color mutedFg(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF9CA3AF) : caption;

  static Color cardSurface(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF141414) : surface;

  static Color cardBorder(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF2A2A2A) : hairline;

  /// 인사이트 한 줄 평 — Serif 느낌(시스템 serif 우선)
  static TextStyle editorialHeadline({
    required Color color,
    double fontSize = 30,
    FontWeight weight = FontWeight.w700,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: weight,
      height: 1.22,
      letterSpacing: -0.4,
      color: color,
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['Times New Roman', 'serif'],
    );
  }

  /// AI 요약·메모 — Sans 본문
  static TextStyle editorialBody({
    required Color color,
    double fontSize = 15,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      height: 1.55,
      color: color,
    );
  }

  static TextStyle editorialCaption({required Color color}) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      color: color,
    );
  }

  static TextStyle editorialMonoHint({required Color color}) {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      color: color,
      fontFamily: 'Menlo',
      fontFamilyFallback: const ['Courier', 'monospace'],
    );
  }
}
