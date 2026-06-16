import 'package:flutter/material.dart';
import '../../core/constants/app_typography.dart';

class TagBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double opacity;

  const TagBadge({
    super.key,
    required this.label,
    required this.color,
    this.opacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: IsleText.badge(color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
