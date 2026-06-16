import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/platform/platform_block_intent.dart';

/// Isle 핵심 가치 — Safari·Chrome 유튜브 차단 → Isle WebView 시청·기록
class YoutubeIsleCoreGuide extends StatelessWidget {
  const YoutubeIsleCoreGuide({
    super.key,
    this.compact = false,
    this.onPrimaryAction,
    this.primaryLabel,
    this.onSecondaryAction,
    this.secondaryLabel,
  });

  final bool compact;
  final VoidCallback? onPrimaryAction;
  final String? primaryLabel;
  final VoidCallback? onSecondaryAction;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    final browser = PlatformBlockCopy.externalBrowserName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _flowRow(browser),
        if (!compact) ...[
          const SizedBox(height: 14),
          Text(
            'Isle를 설치한 이유가 보통 이거예요.\n'
            '① $browser·유튜브 앱에서 youtube.com 차단 ② 링크는 Isle로 열기 ③ 시청 시간·한도 기록',
            style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.45),
          ),
        ],
        const SizedBox(height: 8),
        _bullet(Icons.public_off, '$browser 차단', 'Screen Time · youtube.com'),
        _bullet(Icons.sailing, 'Isle에서 시청', 'WebView = 시간·한도·스케줄 적용'),
        _bullet(Icons.ios_share, '공유·복사 링크', 'KakaoTalk·Safari → Isle로 열기'),
        if (onPrimaryAction != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: IsleSize.minTouchTarget,
            child: FilledButton.icon(
              onPressed: onPrimaryAction,
              icon: const Icon(Icons.track_changes),
              label: Text(primaryLabel ?? '3단계 설정 시작'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
        if (onSecondaryAction != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onSecondaryAction,
            child: Text(secondaryLabel ?? '나중에 · 설정에서 할게요'),
          ),
        ],
      ],
    );
  }

  Widget _flowRow(String browser) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Row(
        children: [
          _node(Icons.language, '$browser\n유튜브', muted: true),
          _arrow(),
          _node(Icons.block, '차단', accent: true),
          _arrow(),
          _node(Icons.play_circle_fill, 'Isle\n재생', accent: true, youtube: true),
          _arrow(),
          _node(Icons.timer_outlined, '시간\n기록', accent: true),
        ],
      ),
    );
  }

  Widget _node(
    IconData icon,
    String label, {
    bool muted = false,
    bool accent = false,
    bool youtube = false,
  }) {
    final bg = muted
        ? IsleColors.sand100
        : youtube
            ? const Color(0xFFFF0000).withValues(alpha: 0.12)
            : IsleColors.ocean100;
    final fg = muted
        ? IsleColors.muted
        : youtube
            ? const Color(0xFFFF0000)
            : IsleColors.ocean700;
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: fg),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: IsleText.caption(color: fg).copyWith(fontSize: 10, height: 1.15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _arrow() => const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: Icon(Icons.arrow_forward, size: 14, color: IsleColors.ocean300),
      );

  Widget _bullet(IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: IsleColors.ocean500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
                Text(sub, style: IsleText.caption(color: IsleColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
