import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

class IsleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;

  const IsleAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              tooltip: '뒤로',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/settings');
                }
              },
            )
          : null,
      title: Text(title, style: IsleText.subtitle(color: IsleColors.ocean900)),
      actions: actions,
      centerTitle: false,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
