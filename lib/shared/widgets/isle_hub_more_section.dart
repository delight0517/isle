import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// 유튜브 허브 등 — 부가 기능 접기 (처음엔 숨김)
class IsleHubMoreSection extends StatefulWidget {
  const IsleHubMoreSection({
    super.key,
    required this.children,
    this.title = '더 보기',
    this.subtitle = '한도·차단·로그인·기타',
  });

  final List<Widget> children;
  final String title;
  final String subtitle;

  @override
  State<IsleHubMoreSection> createState() => _IsleHubMoreSectionState();
}

class _IsleHubMoreSectionState extends State<IsleHubMoreSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: IsleColors.sand100,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
                        Text(widget.subtitle, style: IsleText.caption(color: IsleColors.muted)),
                      ],
                    ),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more, color: IsleColors.muted),
                ],
              ),
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 12),
          ...widget.children,
        ],
      ],
    );
  }
}
