import 'package:flutter/material.dart';

import '../platform/platform_block_intent.dart';

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
    (
      minutes: 5,
      label: '5분 리필 🔄',
      hint: '5분 창에서 N분만 허용 — 카카오·쇼츠·릴스 사용 줄이기에 최적'
    ),
    (minutes: 30, label: '30·10 집중', hint: '30분 누적 후 10분 휴식 — 카카오 쇼츠 포모도로와 함께'),
    (minutes: 60, label: '1시간 리셋', hint: null),
    (minutes: 180, label: '3시간 리셋', hint: null),
    (minutes: 300, label: '5시간 리셋', hint: null),
    (minutes: 1440, label: '매일 리셋', hint: null),
  ];

  static const targets = [
    ScheduleAppTargetDef(
      id: 'isle_youtube',
      label: 'Isle 유튜브',
      subtitle: '앱 안 재생 (/youtube) · Safari 아님',
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
    // "브라우저/인터넷 차단해줘" 채팅이 예전엔 targetId 없이 외부 Safari의
    // Screen Time 수동 선택만 안내했다 — 정작 Isle 자체 인앱 브라우저(웹 탐색
    // 화면, safariGeneric 표면)는 스케줄이 전부(모든 isle 타깃)를 막을 때만
    // 우연히 같이 막히는 부작용으로만 커버됐다(2026-07-12 발견). 이 타깃을
    // 추가해 "브라우저 차단"이 인앱 브라우저를 직접·즉시 막게 한다(Screen Time
    // 권한/선택 불필요, 100% 자동).
    ScheduleAppTargetDef(
      id: 'isle_customweb',
      label: '인앱 브라우저',
      subtitle: 'Isle 자체 웹 탐색 화면 (Safari 아님)',
      kind: ScheduleAppTargetKind.isle,
      bundleId: 'customweb',
      icon: Icons.public_off,
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
      id: 'ios_youtube_music',
      label: 'YouTube Music',
      subtitle: 'iPhone 앱 · 화면만 한도(백그라운드 음악 제외)',
      kind: ScheduleAppTargetKind.ios,
      bundleId: 'youtube_music',
      icon: Icons.music_note,
      androidPackage: 'com.google.android.apps.youtube.music',
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
    ScheduleAppTargetDef(
      id: 'ios_safari',
      label: 'Safari',
      subtitle: 'iPhone 앱',
      kind: ScheduleAppTargetKind.ios,
      bundleId: 'safari',
      icon: Icons.phone_iphone,
    ),
    // Safari 안 youtube.com 자체는 OS 콘텐츠 필터를 걸면 Isle 인앱 재생까지
    // 깨지는 과거 버그 때문에 걸지 않는다(TODO.md 참고) — 대신 Chrome처럼
    // 별도로 설치된 브라우저 앱은 이 타깃으로 등록해 앱 단위로 통째로 막을
    // 수 있게 한다(2026-[REDACTED], 유튜브 우회 경로 대응).
    ScheduleAppTargetDef(
      id: 'ios_chrome',
      label: 'Chrome',
      subtitle: 'iPhone 앱 · 브라우저',
      kind: ScheduleAppTargetKind.ios,
      bundleId: 'chrome',
      icon: Icons.phone_iphone,
      androidPackage: 'com.android.chrome',
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
      id: 'youtube_music',
      label: 'YouTube Music · 화면 한도',
      targetIds: ['ios_youtube_music'],
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
      id: 'customweb',
      label: '인앱 브라우저 차단',
      targetIds: ['isle_customweb'],
    ),
    ScheduleAppBundleDef(
      id: 'kakao_talk',
      label: '카카오톡 · 쇼츠',
      targetIds: ['ios_kakao'],
    ),
    ScheduleAppBundleDef(
      id: 'safari',
      label: 'Safari 앱',
      targetIds: ['ios_safari'],
    ),
    ScheduleAppBundleDef(
      id: 'chrome',
      label: 'Chrome 차단',
      targetIds: ['ios_chrome'],
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

  /// UI용 — Android에서는 「Android 앱」 등으로 표시
  static String displaySubtitle(ScheduleAppTargetDef def) {
    if (!def.isIos) return def.subtitle;
    if (def.id == 'ios_youtube_music') {
      return '${PlatformBlockCopy.nativeInstalledAppLabel} · 화면만 한도(백그라운드 음악 제외)';
    }
    if (def.id == 'ios_kakao') {
      return '${PlatformBlockCopy.nativeInstalledAppLabel} · 쇼츠 포함';
    }
    return PlatformBlockCopy.nativeInstalledAppLabel;
  }
}
