import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';

/// 유튜브 시청 중 스와이프 다운 → 하단 미니 플레이어 + 상단 탐색 WebView 레이아웃
class YoutubeInlineMiniLayout {
  YoutubeInlineMiniLayout._();

  static const navBarHeight = 44.0;

  static double playerHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 9 / 16).clamp(140.0, 220.0);
  }

  static double totalBottomReserved(BuildContext context, double bottomInset) {
    return bottomInset + playerHeight(context) + navBarHeight;
  }
}

class YoutubeInlineMiniNavBar extends StatelessWidget {
  const YoutubeInlineMiniNavBar({
    super.key,
    required this.onHome,
    required this.onSearch,
    required this.onWatchLater,
    required this.onIsleLibrary,
    this.onIsleLongPress,
    required this.onExpand,
  });

  final VoidCallback onHome;
  final VoidCallback onSearch;
  final VoidCallback onWatchLater;
  final VoidCallback onIsleLibrary;
  final VoidCallback? onIsleLongPress;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF212121),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: YoutubeInlineMiniLayout.navBarHeight,
          child: Row(
            children: [
              _NavBtn(icon: Icons.home_outlined, label: '홈', onTap: onHome),
              _NavBtn(icon: Icons.search, label: '검색', onTap: onSearch),
              _NavBtn(
                icon: Icons.watch_later_outlined,
                label: '나중에',
                onTap: onWatchLater,
              ),
              _NavIsleBtn(
                onTap: onIsleLibrary,
                onLongPress: onIsleLongPress,
              ),
              const Spacer(),
              IconButton(
                tooltip: '영상 크게',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onExpand();
                },
                icon: const Icon(Icons.open_in_full, color: Colors.white70, size: 22),
                style: IconButton.styleFrom(
                  minimumSize: const Size(IsleSize.minTouchTarget, IsleSize.minTouchTarget),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIsleBtn extends StatelessWidget {
  const _NavIsleBtn({required this.onTap, this.onLongPress});

  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      onLongPress: onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onLongPress!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library_outlined, color: Colors.white, size: 22),
            const SizedBox(height: 2),
            Text('Isle', style: IsleText.caption(color: IsleColors.gold500).copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(height: 2),
            Text(label, style: IsleText.caption(color: Colors.white54).copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

/// 시청 화면 상단 — 아래로 스와이프해 미니 플레이어 진입
class YoutubeInlineMiniSwipeHint extends StatelessWidget {
  const YoutubeInlineMiniSwipeHint({super.key, required this.onSwipeDown});

  final VoidCallback onSwipeDown;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v > 420) onSwipeDown();
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swipe_down, size: 14, color: IsleColors.gold500.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
              Text(
                '아래로 스와이프 · 탐색',
                style: IsleText.caption(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class YoutubeInlineMiniPlayerChrome extends StatelessWidget {
  const YoutubeInlineMiniPlayerChrome({
    super.key,
    required this.title,
    required this.onExpand,
    required this.onClose,
  });

  final String title;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < -420) {
                HapticFeedback.lightImpact();
                onExpand();
              }
            },
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 4),
              width: 36,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.black.withValues(alpha: 0.55),
            child: Row(
              children: [
                const Icon(Icons.play_circle_fill, color: Color(0xFFFF0000), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: IsleText.caption(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_full, color: Colors.white70, size: 20),
                  onPressed: onExpand,
                  visualDensity: VisualDensity.compact,
                  tooltip: '크게 보기',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                  tooltip: '미니 종료',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
