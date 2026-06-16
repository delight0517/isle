import 'package:flutter/material.dart';

/// 스케줄에서 고를 수 있는 차단·한도 대상 (Isle / iPhone 분리)
class ScheduleAppTargetDef {
  const ScheduleAppTargetDef({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.kind,
    required this.bundleId,
    this.icon = Icons.apps,
    this.androidPackage,
  });

  final String id;
  final String label;
  final String subtitle;
  final ScheduleAppTargetKind kind;
  /// 한도는 번들 단위로 합산 (예: Isle 인스타 + DM + iOS 인스타)
  final String bundleId;
  final IconData icon;
  final String? androidPackage;

  bool get isIsle => kind == ScheduleAppTargetKind.isle;
  bool get isIos => kind == ScheduleAppTargetKind.ios;
}

enum ScheduleAppTargetKind { isle, ios }

class ScheduleAppBundleDef {
  const ScheduleAppBundleDef({
    required this.id,
    required this.label,
    required this.targetIds,
  });

  final String id;
  final String label;
  final List<String> targetIds;
}

class ScheduleAppTargetCatalog {
  ScheduleAppTargetCatalog._();

  static const windowPresets = <({int minutes, String label, String? hint})>[
    (minutes: 5, label: '5분 리필 🔄', hint: '5분 창에서 N분만 허용 — 카카오·쇼츠·릴스 끊기에 최적'),
    (minutes: 30, label: '30·10 집중', hint: '30분 누적 후 10분 휴식 — 카카오 쇼츠 포모도로와 함께'),
    (minutes: 60, label: '1시간 리셋', hint: null),
    (minutes: 180, label: '3시간 리셋', hint: null),
    (minutes: 300, label: '5시간 리셋', hint: null),
    (minutes: 1440, label: '매일 리셋', hint: null),
  ];

  static const targets = [
    ScheduleAppTargetDef(
      id: 'isle_youtube',
      label: 'YouTube',
      subtitle: 'Isle 앱 안',
      kind: ScheduleAppTargetKind.isle,
      bundleId: 'youtube',
      icon: Icons.play_circle_filled,
    ),
    ScheduleAppTargetDef(
      id: 'isle_instagram',
      label: 'Instagram',
      subtitle: 'Isle · 피드·탐색',
      kind: ScheduleAppTargetKind.isle,
      bundleId: 'instagram_feed',
      icon: Icons.camera_alt_outlined,
    ),
    ScheduleAppTargetDef(
      id: 'isle_instagram_dm',
      label: 'Instagram DM',
      subtitle: 'Isle · 메시지',
      kind: ScheduleAppTargetKind.isle,
      bundleId: 'instagram_dm',
      icon: Icons.forum_outlined,
    ),
    ScheduleAppTargetDef(
      id: 'isle_brunch',
      label: 'Brunch',
      subtitle: 'Isle 앱 안',
      kind: ScheduleAppTargetKind.isle,
      bundleId: 'brunch',
      icon: Icons.article_outlined,
    ),
    ScheduleAppTargetDef(
      id: 'ios_instagram',
      label: 'Instagram',
      subtitle: 'iPhone 앱',
      kind: ScheduleAppTargetKind.ios,
      bundleId: 'instagram_feed',
      icon: Icons.phone_iphone,
      androidPackage: 'com.instagram.android',
    ),
    ScheduleAppTargetDef(
      id: 'ios_tiktok',
      label: 'TikTok',
      subtitle: 'iPhone 앱',
      kind: ScheduleAppTargetKind.ios,
      bundleId: 'tiktok',
      icon: Icons.phone_iphone,
      androidPackage: 'com.zhiliaoapp.musically',
    ),
    ScheduleAppTargetDef(
      id: 'ios_youtube',
      label: 'YouTube',
      subtitle: 'iPhone 앱',
      kind: ScheduleAppTargetKind.ios,
      bundleId: 'youtube',
      icon: Icons.phone_iphone,
      androidPackage: 'com.google.android.youtube',
    ),
    ScheduleAppTargetDef(
      id: 'ios_kakao',
      label: '카카오톡',
      subtitle: 'iPhone · 쇼츠 포함',
      kind: ScheduleAppTargetKind.ios,
      bundleId: 'kakao_talk',
      icon: Icons.phone_iphone,
      androidPackage: 'com.kakao.talk',
    ),
  ];

  static const bundles = [
    ScheduleAppBundleDef(
      id: 'instagram_feed',
      label: 'Instagram 피드 · 한도',
      targetIds: ['isle_instagram', 'ios_instagram'],
    ),
    ScheduleAppBundleDef(
      id: 'instagram_dm',
      label: 'Instagram DM · 한도',
      targetIds: ['isle_instagram_dm'],
    ),
    ScheduleAppBundleDef(
      id: 'youtube',
      label: 'YouTube 시간 한도',
      targetIds: ['isle_youtube', 'ios_youtube'],
    ),
    ScheduleAppBundleDef(
      id: 'tiktok',
      label: 'TikTok 시간 한도',
      targetIds: ['ios_tiktok'],
    ),
    ScheduleAppBundleDef(
      id: 'brunch',
      label: 'Brunch 시간 한도',
      targetIds: ['isle_brunch'],
    ),
    ScheduleAppBundleDef(
      id: 'kakao_talk',
      label: '카카오톡 · 쇼츠',
      targetIds: ['ios_kakao'],
    ),
  ];

  static ScheduleAppTargetDef? defFor(String targetId) {
    for (final t in targets) {
      if (t.id == targetId) return t;
    }
    return null;
  }

  static ScheduleAppBundleDef? bundleFor(String bundleId) {
    for (final b in bundles) {
      if (b.id == bundleId) return b;
    }
    return null;
  }

  static List<ScheduleAppTargetDef> isleTargets() =>
      targets.where((t) => t.isIsle).toList();

  static List<ScheduleAppTargetDef> iosTargets() =>
      targets.where((t) => t.isIos).toList();
}
