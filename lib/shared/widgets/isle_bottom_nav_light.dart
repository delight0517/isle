import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class IsleBottomNavLight extends StatelessWidget {
  const IsleBottomNavLight({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: IsleColors.ocean100,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.play_circle_outline),
          selectedIcon: Icon(Icons.play_circle),
          label: '유튜브',
        ),
        NavigationDestination(
          icon: Icon(Icons.block_outlined),
          selectedIcon: Icon(Icons.block),
          label: '차단',
        ),
        NavigationDestination(
          icon: Icon(Icons.schedule_outlined),
          selectedIcon: Icon(Icons.schedule),
          label: '스케줄',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: '설정',
        ),
      ],
    );
  }
}
