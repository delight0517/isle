import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/library/models/library_entry.dart';
import '../../../../core/library/my_isle_content_groups.dart';

class MyIsleEntryTile extends StatelessWidget {
  const MyIsleEntryTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final LibraryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.thumbnailUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    entry.thumbnailUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                  ),
                )
              else
                _thumbPlaceholder(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${MyIsleContentGroups.originLabel(entry.origin)}'
                      '${entry.channelName.isNotEmpty ? ' · ${entry.channelName}' : ''}',
                      style: IsleText.caption(color: IsleColors.muted),
                    ),
                    if (entry.summary != null && entry.summary!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: IsleText.caption(color: IsleColors.ocean700),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: IsleColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: IsleColors.ocean100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.article_outlined, color: IsleColors.ocean500),
    );
  }
}
