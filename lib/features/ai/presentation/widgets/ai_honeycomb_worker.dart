import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// 노란 육각 꿀벌집 + 남색 배경 — AI 작업·전송 중 시각화
class AiHoneycombWorker extends StatefulWidget {
  const AiHoneycombWorker({
    super.key,
    this.size = 72,
    this.active = true,
    this.showOutbound = true,
  });

  final double size;
  final bool active;
  final bool showOutbound;

  @override
  State<AiHoneycombWorker> createState() => _AiHoneycombWorkerState();
}

class _AiHoneycombWorkerState extends State<AiHoneycombWorker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant AiHoneycombWorker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.active) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _HoneycombPainter(
            t: widget.active ? _ctrl.value : 0,
            showOutbound: widget.showOutbound && widget.active,
          ),
          size: Size.square(widget.size),
        ),
      ),
    );
  }
}

class _HoneycombPainter extends CustomPainter {
  _HoneycombPainter({required this.t, required this.showOutbound});

  final double t;
  final bool showOutbound;

  static const _navy = Color(0xFF0B1538);
  static const _navyGlow = Color(0xFF1A2B6B);
  static const _hexFill = Color(0x33FFD54F);
  static const _hexStroke = Color(0xFFFFD54F);
  static const _hexCore = Color(0xFFFFC107);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.18;
    final drift = Offset(math.sin(t * math.pi * 2) * 3, math.cos(t * math.pi * 2 * 0.7) * 2.5);

    final bg = Paint()
      ..shader = RadialGradient(
        colors: [_navyGlow, _navy],
        stops: const [0.35, 1],
      ).createShader(Rect.fromCircle(center: c, radius: size.shortestSide * 0.55));
    canvas.drawCircle(c, size.shortestSide * 0.52, bg);

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _hexStroke.withValues(alpha: 0.55 + 0.25 * math.sin(t * math.pi * 2));

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _hexFill;

    final positions = <Offset>[
      Offset.zero,
      Offset(r * 1.75, 0),
      Offset(-r * 1.75, 0),
      Offset(r * 0.875, r * 1.52),
      Offset(-r * 0.875, r * 1.52),
      Offset(r * 0.875, -r * 1.52),
      Offset(-r * 0.875, -r * 1.52),
    ];

    for (var i = 0; i < positions.length; i++) {
      final phase = (t + i * 0.11) % 1.0;
      final wobble = Offset(
        math.sin(phase * math.pi * 2) * 1.5,
        math.cos(phase * math.pi * 2) * 1.2,
      );
      final center = c + drift + positions[i] + wobble;
      final path = _hexPath(center, r * (i == 0 ? 1.05 : 0.92));
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, gridPaint);
      if (i == 0) {
        final core = Paint()
          ..color = _hexCore.withValues(alpha: 0.35 + 0.2 * math.sin(t * math.pi * 4));
        canvas.drawPath(_hexPath(center, r * 0.55), core);
      }
    }

    if (showOutbound) {
      final packetPaint = Paint()..color = _hexStroke;
      for (var i = 0; i < 5; i++) {
        final p = ((t * 1.4 + i * 0.18) % 1.0);
        final start = c + drift;
        final end = Offset(size.width * 0.92, size.height * 0.12);
        final pos = Offset.lerp(start, end, Curves.easeInOut.transform(p))!;
        canvas.drawCircle(
          pos,
          2.2 + math.sin(p * math.pi) * 1.2,
          packetPaint..color = Color.lerp(_hexCore, IsleColors.gold500, p)!,
        );
      }
      final beam = Paint()
        ..shader = LinearGradient(
          colors: [
            _hexStroke.withValues(alpha: 0),
            _hexStroke.withValues(alpha: 0.35),
            _hexStroke.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final beamPath = Path()
        ..moveTo(c.dx + drift.dx, c.dy + drift.dy)
        ..quadraticBezierTo(
          size.width * 0.7,
          size.height * 0.2,
          size.width * 0.95,
          size.height * 0.08,
        );
      canvas.drawPath(beamPath, beam);
    }
  }

  Path _hexPath(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 6 + i * math.pi / 3;
      final p = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HoneycombPainter old) => old.t != t || old.showOutbound != showOutbound;
}
