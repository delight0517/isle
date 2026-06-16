import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../providers/feed_provider.dart';

class InterestFilterChips extends ConsumerWidget {
  const InterestFilterChips({super.key});

  static const _topics = ['기술/IT', '재무/투자', '디자인', '철학/인문', '자기계발', '전체'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeFeedFilterProvider);
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: _topics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = _topics[i];
          final isAll = label == '전체';
          final selected = isAll ? active == null : active == label;
          return FilterChip(
            selected: selected,
            label: Text(label, style: IsleText.caption(color: selected ? Colors.white : IsleColors.ocean700)),
            selectedColor: IsleColors.ocean500,
            backgroundColor: IsleColors.ocean100,
            showCheckmark: false,
            onSelected: (_) {
              ref.read(activeFeedFilterProvider.notifier).state = isAll ? null : label;
            },
          );
        },
      ),
    );
  }
}
