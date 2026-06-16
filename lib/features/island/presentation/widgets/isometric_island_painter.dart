import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/island/island_theme_palette.dart';
import '../../data/models/shelf.dart';

class IsometricIslandPainter extends CustomPainter {
  final List<Shelf> shelves;
  final String? tappedShelfId;
  final IslandThemePalette palette;

  static const double tileW = 80.0;
  static const double tileH = 40.0;
  static const double shelfH = 80.0;

  const IsometricIslandPainter({
    required this.shelves,
    this.tappedShelfId,
    this.palette = IslandThemePalette.classic,
  });

  Offset _gridToIso(double gx, double gy, Offset center) => Offset(
        center.dx + (gx - gy) * tileW / 2,
        center.dy + (gx + gy) * tileH / 2,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);

    _drawIsland(canvas, center);

    final sorted = [...shelves]..sort((a, b) => (a.positionX + a.positionY).compareTo(b.positionX + b.positionY));

    for (final shelf in sorted) {
      final pos = _gridToIso(shelf.positionX.toDouble(), shelf.positionY.toDouble(), center);
      _drawShelfBlock(canvas, pos, shelf);
      _drawShelfLabel(canvas, pos, shelf.title);
    }
  }

  void _drawIsland(Canvas canvas, Offset c) {
    const r = 3.0;
    final top = Path()
      ..moveTo(c.dx, c.dy - tileH * r)
      ..lineTo(c.dx + tileW * r, c.dy)
      ..lineTo(c.dx, c.dy + tileH * r)
      ..lineTo(c.dx - tileW * r, c.dy)
      ..close();
    final left = Path()
      ..moveTo(c.dx - tileW * r, c.dy)
      ..lineTo(c.dx, c.dy + tileH * r)
      ..lineTo(c.dx, c.dy + tileH * r + 18)
      ..lineTo(c.dx - tileW * r, c.dy + 18)
      ..close();
    final right = Path()
      ..moveTo(c.dx + tileW * r, c.dy)
      ..lineTo(c.dx, c.dy + tileH * r)
      ..lineTo(c.dx, c.dy + tileH * r + 18)
      ..lineTo(c.dx + tileW * r, c.dy + 18)
      ..close();

    canvas.drawPath(top, Paint()..color = palette.grassTop);
    canvas.drawPath(left, Paint()..color = palette.grassLeft);
    canvas.drawPath(right, Paint()..color = palette.grassRight);
  }

  void _drawShelfBlock(Canvas canvas, Offset pos, Shelf shelf) {
    const w = tileW * 0.75;
    const h = shelfH;
    final isTapped = shelf.id == tappedShelfId;
    final scale = isTapped ? 1.06 : 1.0;
    final scaledW = w * scale;
    final scaledH = h * scale;

    final topFace = Path()
      ..moveTo(pos.dx, pos.dy - scaledH)
      ..lineTo(pos.dx + scaledW / 2, pos.dy - scaledH + tileH / 2)
      ..lineTo(pos.dx, pos.dy - scaledH + tileH)
      ..lineTo(pos.dx - scaledW / 2, pos.dy - scaledH + tileH / 2)
      ..close();

    final leftFace = Path()
      ..moveTo(pos.dx - scaledW / 2, pos.dy - scaledH + tileH / 2)
      ..lineTo(pos.dx, pos.dy - scaledH + tileH)
      ..lineTo(pos.dx, pos.dy)
      ..lineTo(pos.dx - scaledW / 2, pos.dy - tileH / 2)
      ..close();

    final rightFace = Path()
      ..moveTo(pos.dx, pos.dy - scaledH + tileH)
      ..lineTo(pos.dx + scaledW / 2, pos.dy - scaledH + tileH / 2)
      ..lineTo(pos.dx + scaledW / 2, pos.dy - tileH / 2)
      ..lineTo(pos.dx, pos.dy)
      ..close();

    canvas.drawPath(topFace, Paint()..color = IsleColors.woodMid);
    canvas.drawPath(leftFace, Paint()..color = IsleColors.woodDark);
    canvas.drawPath(rightFace, Paint()..color = IsleColors.woodLight);

    _drawBooks(canvas, pos, shelf.colorHex);
  }

  void _drawBooks(Canvas canvas, Offset pos, String colorHex) {
    Color bookColor;
    try {
      bookColor = Color(int.parse(colorHex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      bookColor = IsleColors.ocean500;
    }

    final rng = math.Random(pos.dx.toInt() * 31 + pos.dy.toInt());
    var x = pos.dx - tileW * 0.28;
    final baseY = pos.dy - 4;

    for (var i = 0; i < 5; i++) {
      final bH = 22.0 + rng.nextDouble() * 18;
      final bW = 7.0 + rng.nextDouble() * 5;
      final opacity = 0.6 + rng.nextDouble() * 0.4;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseY - bH, bW, bH),
          const Radius.circular(2),
        ),
        Paint()..color = bookColor.withValues(alpha: opacity),
      );
      x += bW + 1.5;
    }
  }

  void _drawShelfLabel(Canvas canvas, Offset pos, String title) {
    final tp = TextPainter(
      text: TextSpan(
        text: title,
        style: IsleText.badge(color: Colors.white).copyWith(
          shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - shelfH - 18));
  }

  @override
  bool shouldRepaint(IsometricIslandPainter old) =>
      old.shelves != shelves ||
      old.tappedShelfId != tappedShelfId ||
      old.palette.id != palette.id;
}
