import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/app_dimensions.dart';

class FeedCardSkeleton extends StatelessWidget {
  const FeedCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEEEEEE),
      highlightColor: const Color(0xFFF8F8F8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: IsleSize.screenPadding, vertical: IsleSize.cardGap),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(IsleSize.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: IsleSize.thumbnailH,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(IsleSize.cardRadius)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(IsleSize.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: double.infinity, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(height: 16, width: 200, color: Colors.white),
                  const SizedBox(height: 10),
                  Container(height: 12, width: 100, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
