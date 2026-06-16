import 'package:flutter/material.dart';

/// 4vpnBlocker `RulePreset` · Valley 프리셋을 Isle 앱 차단 UX에 맞게 단순화.
class AppInterventionPreset {
  const AppInterventionPreset({
    required this.id,
    required this.title,
    required this.detail,
    required this.icon,
    required this.tint,
    this.suggestYoutubeWebBlock = false,
    this.suggestScheduleName,
    this.guideBullets = const [],
  });

  final String id;
  final String title;
  final String detail;
  final IconData icon;
  final Color tint;
  final bool suggestYoutubeWebBlock;
  final String? suggestScheduleName;
  final List<String> guideBullets;

  static const schoolMode = AppInterventionPreset(
    id: 'school',
    title: '집중 모드',
    detail: '유튜브 앱·SNS·게임을 골라 두고, 공부 시간대에는 Isle 차단 스케줄과 함께 씁니다.',
    icon: Icons.school_outlined,
    tint: Color(0xFF4A6FA5),
    suggestScheduleName: '차단 시간',
    guideBullets: [
      '시스템 피커에서 YouTube · Instagram · TikTok 등을 선택',
      '설정 → 차단 스케줄에서 평일 낮 시간대 추가',
      'Safari 유튜브는 아래 「브라우저 유튜브 차단」으로 보완',
    ],
  );

  static const nightWindDown = AppInterventionPreset(
    id: 'night',
    title: '밤 바람 쉬기',
    detail: '저녁~취침 전에 쇼츠·SNS를 막고 Isle WebView로만 보고 싶을 때.',
    icon: Icons.nightlight_round,
    tint: Color(0xFF5C4D7A),
    suggestYoutubeWebBlock: true,
    suggestScheduleName: '밤 차단',
    guideBullets: [
      '유튜브 앱 + SNS 카테고리 선택 권장',
      '브라우저 유튜브 차단을 켜면 Safari에서도 열리지 않음',
      'Isle 안에서는 「유튜브 시청 한도」로 분 단위 통제',
    ],
  );

  static const socialDetox = AppInterventionPreset(
    id: 'social',
    title: 'SNS 디톡스',
    detail: '인스타·틱톡·X 등만 골라 차단. 피드는 Isle에서 구독 채널만.',
    icon: Icons.self_improvement_outlined,
    tint: Color(0xFF2D6A5A),
    guideBullets: [
      'SNS 앱만 피커에서 선택 (카테고리 「소셜」도 가능)',
      'Isle WebView 인스타는 「플랫폼 시청 한도」로 별도 관리',
    ],
  );

  static const all = [schoolMode, nightWindDown, socialDetox];
}
