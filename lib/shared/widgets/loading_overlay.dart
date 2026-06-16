import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class LoadingOverlay extends StatelessWidget {
  final bool visible;
  final Widget child;
  const LoadingOverlay({super.key, required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          const ColoredBox(
            color: Color(0x66000000),
            child: Center(
              child: CircularProgressIndicator(color: IsleColors.gold500),
            ),
          ),
      ],
    );
  }
}
