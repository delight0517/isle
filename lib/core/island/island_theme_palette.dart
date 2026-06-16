import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// 섬 3D 뷰 색 조합 — 로컬·프로필 동기화용 ID
class IslandThemePalette {
  const IslandThemePalette({
    required this.id,
    required this.labelKo,
    required this.skyTop,
    required this.skyBottom,
    required this.grassTop,
    required this.grassLeft,
    required this.grassRight,
  });

  final String id;
  final String labelKo;
  final Color skyTop;
  final Color skyBottom;
  final Color grassTop;
  final Color grassLeft;
  final Color grassRight;

  static const classic = IslandThemePalette(
    id: 'classic',
    labelKo: '클래식 바다',
    skyTop: IsleColors.ocean900,
    skyBottom: Color(0xFF1E3A5F),
    grassTop: IsleColors.grass,
    grassLeft: IsleColors.grassDark,
    grassRight: IsleColors.grassDeep,
  );

  static const midnight = IslandThemePalette(
    id: 'midnight',
    labelKo: '미드나잇',
    skyTop: Color(0xFF0D1117),
    skyBottom: Color(0xFF1A1F35),
    grassTop: const Color(0xFF2D4A3E),
    grassLeft: const Color(0xFF1E3329),
    grassRight: const Color(0xFF152820),
  );

  static const sunset = IslandThemePalette(
    id: 'sunset',
    labelKo: '선셋 모래',
    skyTop: const Color(0xFF4A2C2A),
    skyBottom: const Color(0xFF8B4513),
    grassTop: IsleColors.sand100,
    grassLeft: IsleColors.sand500,
    grassRight: IsleColors.sand900,
  );

  static const aurora = IslandThemePalette(
    id: 'aurora',
    labelKo: '오로라',
    skyTop: const Color(0xFF1B2838),
    skyBottom: const Color(0xFF2E1F4E),
    grassTop: const Color(0xFF3D6B5A),
    grassLeft: const Color(0xFF2A4D42),
    grassRight: const Color(0xFF1F3A32),
  );

  static const all = [classic, midnight, sunset, aurora];

  static IslandThemePalette byId(String? id) {
    return all.firstWhere(
      (t) => t.id == id,
      orElse: () => classic,
    );
  }
}
