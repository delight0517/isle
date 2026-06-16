import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// 공유·저장 화면 — 링크가 카드 안으로 흡수되는 듯한 Flip 애니메이션
class LinkAbsorbHero extends StatefulWidget {
  const LinkAbsorbHero({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.title,
    this.loading = false,
  });

  final String url;
  final String? thumbnailUrl;
  final String? title;
  final bool loading;

  @override
  State<LinkAbsorbHero> createState() => _LinkAbsorbHeroState();
}

class _LinkAbsorbHeroState extends State<LinkAbsorbHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _flip;
  bool _wasLoading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _flip = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(LinkAbsorbHero old) {
    super.didUpdateWidget(old);
    if (_wasLoading && !widget.loading && (widget.thumbnailUrl?.isNotEmpty ?? false)) {
      _ctrl.forward(from: 0);
    }
    _wasLoading = widget.loading;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flip,
      builder: (_, __) {
        final t = _flip.value;
        final showBack = t >= 0.5;
        final angle = t * 3.14159;
        return Column(
          children: [
            SizedBox(
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: showBack ? _backFace() : _frontFace(),
                  ),
                  if (widget.loading)
                    const Positioned(
                      right: 12,
                      bottom: 12,
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.loading
                  ? '링크 삼키는 중…'
                  : (widget.title?.isNotEmpty == true ? widget.title! : '저장 준비됨'),
              style: IsleText.subtitle(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.url,
              style: IsleText.caption(color: IsleColors.muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  Widget _frontFace() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            IsleColors.ocean500.withValues(alpha: 0.15),
            IsleColors.gold500.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.link, size: 40, color: IsleColors.ocean700),
          const SizedBox(height: 8),
          Text('링크 흡수', style: IsleText.body(color: IsleColors.ocean700)),
        ],
      ),
    );
  }

  Widget _backFace() {
    final thumb = widget.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(thumb, fit: BoxFit.cover),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: IsleColors.ocean100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.check_circle, color: IsleColors.ocean700, size: 48),
    );
  }
}
