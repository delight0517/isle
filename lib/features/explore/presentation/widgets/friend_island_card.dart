import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../island/data/models/shelf.dart';
import '../../../island/presentation/widgets/isometric_island_painter.dart';

class FriendIslandData {
  final String name;
  final List<String> interests;
  final List<Shelf> shelves;
  /// 설정 시 카드 탭으로 해당 유저 섬으로 이동
  final String? userId;
  const FriendIslandData({
    required this.name,
    required this.interests,
    required this.shelves,
    this.userId,
  });
}

class FriendIslandCard extends StatelessWidget {
  final FriendIslandData data;
  const FriendIslandCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: 130,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: IsleColors.ocean900,
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
      ),
      child: Column(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(IsleSize.cardRadius)),
            child: CustomPaint(
              painter: IsometricIslandPainter(shelves: data.shelves),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(IsleSize.cardRadius)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data.name, style: IsleText.caption()),
            Wrap(
              spacing: 2,
              children: data.interests.take(2).map((t) => TagChip(label: t)).toList(),
            ),
          ]),
        ),
      ]),
    );
    if (data.userId == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
        onTap: () => context.push('/island/${data.userId}'),
        child: card,
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  final String label;
  const TagChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: IsleColors.ocean100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: IsleText.badge(color: IsleColors.ocean500)),
      );
}
