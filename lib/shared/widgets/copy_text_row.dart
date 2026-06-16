import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// 탭 한 번으로 클립보드 복사 (초보자용)
class CopyTextRow extends StatelessWidget {
  final String label;
  final String value;

  const CopyTextRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IsleColors.ocean100.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('「$label」복사됨 — 붙여넣기 하세요'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: IsleText.caption(color: IsleColors.muted)),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('복사했어요')),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('복사'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
