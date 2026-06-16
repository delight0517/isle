import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/focus/isle_product_focus.dart';
class IsleBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onCenterLongPress;

  const IsleBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onCenterLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (IsleProductFocus.enabled) {
      return _FocusBottomNav(
        currentIndex: currentIndex.clamp(0, 2),
        onTap: onTap,
        onCenterLongPress: onCenterLongPress,
      );
    }

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: IsleColors.ocean100,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '피드'),
        NavigationDestination(icon: Icon(Icons.cabin_outlined), selectedIcon: Icon(Icons.cabin), label: '내 섬'),
        NavigationDestination(
          icon: Icon(Icons.camera_alt_outlined),
          selectedIcon: Icon(Icons.camera_alt),
          label: '소셜',
        ),
        NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: '탐색'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '설정'),
      ],
    );
  }
}

class _FocusBottomNav extends StatelessWidget {
  const _FocusBottomNav({
    required this.currentIndex,
    required this.onTap,
    this.onCenterLongPress,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onCenterLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: IsleSize.bottomNavH,
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: '차단·스케줄',
                  child: _SideItem(
                    index: 0,
                    currentIndex: currentIndex,
                    icon: Icons.shield_outlined,
                    selectedIcon: Icons.shield,
                    label: '차단',
                    onTap: onTap,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Tooltip(
                  message: '탭: 나의 Isle · 길게: 유튜브·인스타 바로 열기',
                  child: _CenterIsleButton(
                    selected: currentIndex == 1,
                    onTap: () => onTap(1),
                    onLongPress: onCenterLongPress,
                  ),
                ),
              ),
              Expanded(
                child: Tooltip(
                  message: '받기·소통 — 링크·DM',
                  child: _SideItem(
                    index: 2,
                    currentIndex: currentIndex,
                    icon: Icons.inbox_outlined,
                    selectedIcon: Icons.inbox,
                    label: '받기',
                    onTap: onTap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = currentIndex == index;
    final color = selected ? IsleColors.ocean700 : IsleColors.muted;
    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? selectedIcon : icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(label, style: IsleText.caption(color: color)),
        ],
      ),
    );
  }
}

class _CenterIsleButton extends StatelessWidget {
  const _CenterIsleButton({
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onLongPress!();
            },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? IsleColors.ocean100 : Colors.transparent,
              border: Border.all(
                color: selected ? IsleColors.ocean500 : IsleColors.ocean100,
                width: selected ? 2 : 1,
              ),
            ),
            child: Icon(
              Icons.landscape_outlined,
              color: selected ? IsleColors.ocean700 : IsleColors.ocean500,
              size: 32,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '나의 Isle',
            style: IsleText.caption(
              color: selected ? IsleColors.ocean700 : IsleColors.muted,
            ).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
