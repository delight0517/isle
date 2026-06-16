import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 다른 사람 섬 보기 진입 — 구름이 화면을 덮는 전환
Future<void> runIslandCloudTransition(
  BuildContext context,
  Future<void> Function() afterCover,
) async {
  late OverlayEntry overlay;
  overlay = OverlayEntry(
    builder: (ctx) => _IslandCloudCover(
      onCovered: () async {
        await afterCover();
        if (ctx.mounted) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      },
      onDone: () => overlay.remove(),
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(overlay);
}

class _IslandCloudCover extends StatefulWidget {
  const _IslandCloudCover({
    required this.onCovered,
    required this.onDone,
  });

  final Future<void> Function() onCovered;
  final VoidCallback onDone;

  @override
  State<_IslandCloudCover> createState() => _IslandCloudCoverState();
}

class _IslandCloudCoverState extends State<_IslandCloudCover> {
  var _phase = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      setState(() => _phase = 1);
      await widget.onCovered();
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() => _phase = 2);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      ignoring: _phase == 2,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            AnimatedOpacity(
              opacity: _phase == 2 ? 0 : 1,
              duration: 400.ms,
              child: Container(color: const Color(0xFFB8D4E8)),
            ),
            ...List.generate(8, (i) {
              final left = (i % 4) * (size.width / 3) - 40;
              final top = (i ~/ 4) * (size.height / 3) - 60;
              return Positioned(
                left: left,
                top: top,
                child: _CloudBlob(size: 120 + (i % 3) * 40)
                    .animate(
                      onPlay: (c) => c.repeat(reverse: true),
                    )
                    .moveY(
                      begin: _phase == 0 ? 80 : 0,
                      end: 0,
                      duration: 900.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .fadeIn(duration: 400.ms),
              );
            }),
            if (_phase >= 1)
              Center(
                child: Text(
                  '다른 섬으로…',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.95),
                    shadows: const [Shadow(color: Colors.black26, blurRadius: 8)],
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms),
          ],
        ),
      ),
    );
  }
}

class _CloudBlob extends StatelessWidget {
  const _CloudBlob({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 1.6, size * 0.9),
      painter: _CloudPainter(),
    );
  }
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    final r = size.height * 0.35;
    final centers = [
      Offset(size.width * 0.25, size.height * 0.55),
      Offset(size.width * 0.5, size.height * 0.45),
      Offset(size.width * 0.75, size.height * 0.55),
      Offset(size.width * 0.4, size.height * 0.7),
      Offset(size.width * 0.65, size.height * 0.68),
    ];
    for (final c in centers) {
      canvas.drawCircle(c, r * (0.85 + math.sin(c.dx) * 0.1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
