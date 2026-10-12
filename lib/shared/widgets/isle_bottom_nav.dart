import 'package:flutter/material.dart';
import '../../core/localization/moa_strings.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/focus/isle_product_focus.dart';
class IsleBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onCenterTap;
  final VoidCallback? onCenterLongPress;

  const IsleBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onCenterTap,
    this.onCenterLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (IsleProductFocus.enabled) {
      return _FocusBottomNav(
        currentIndex: currentIndex.clamp(0, 2),
        onTap: onTap,
        onCenterTap: onCenterTap,
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
    this.onCenterTap,
    this.onCenterLongPress,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onCenterTap;
  final VoidCallback? onCenterLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF0EEFF), width: 1)),
        ),
        child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: 'SNS 바로 열기',
                  child: _SideItem(
                    index: 0,
                    currentIndex: currentIndex,
                    icon: Icons.apps_outlined,
                    selectedIcon: Icons.apps,
                    label: 'SNS',
                    onTap: onTap,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Tooltip(
                  message: '탭: 빠른 실행(QR·앱) · 길게: 유튜브·인스타 바로 열기',
                  child: _CenterIsleButton(
                    selected: currentIndex == 1,
                    onTap: onCenterTap ?? () => onTap(1),
                    onLongPress: onCenterLongPress,
                  ),
                ),
              ),
              Expanded(
                child: Tooltip(
                  message: '시간 관리 · 사용 통계',
                  child: _SideItem(
                    index: 2,
                    currentIndex: currentIndex,
                    icon: Icons.timer_outlined,
                    selectedIcon: Icons.timer,
                    label: MoaStrings.of(context).t('time'),
                    onTap: onTap,
                  ),
                ),
              ),
            ],
          ),
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
    final color = selected ? IsleColors.purple700 : IsleColors.muted;
    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 32,
            decoration: BoxDecoration(
              color: selected ? IsleColors.purple100 : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(selected ? selectedIcon : icon, color: color, size: 22),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: IsleText.caption(color: color).copyWith(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 50,
            height: 40,
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [IsleColors.purple700, IsleColors.purple500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: selected ? null : IsleColors.purple100,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: IsleColors.purple700.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : null,
            ),
            child: Icon(
              Icons.landscape_outlined,
              color: selected ? Colors.white : IsleColors.purple500,
              size: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            MoaStrings.of(context).t('my_moa'),
            style: IsleText.caption(
              color: selected ? IsleColors.purple700 : IsleColors.muted,
            ).copyWith(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
