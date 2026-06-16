import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// 로봇이 입을 벌리고 링크를 삼키는 애니메이션 위젯.
/// [animating] = true 이면 링크가 날아가 입으로 빨려드는 애니메이션 재생.
class RobotLinkSwallowAnimation extends StatefulWidget {
  const RobotLinkSwallowAnimation({
    super.key,
    this.animating = false,
    this.label = 'YouTube 링크를 여기에 붙여넣기',
  });

  final bool animating;
  final String label;

  @override
  State<RobotLinkSwallowAnimation> createState() => _RobotLinkSwallowAnimationState();
}

class _RobotLinkSwallowAnimationState extends State<RobotLinkSwallowAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _mouthCtrl;
  late final AnimationController _linkCtrl;
  late final Animation<double> _mouthOpen;
  late final Animation<double> _linkX;
  late final Animation<double> _linkOpacity;
  late final Animation<double> _blink;

  @override
  void initState() {
    super.initState();

    // 입 열고 닫기 — 1.1초 루프
    _mouthCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _mouthOpen = CurvedAnimation(parent: _mouthCtrl, curve: Curves.easeInOut);

    // 눈 깜빡임 — 2.8초 주기
    _blink = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 90),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.05), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: 1.0), weight: 5),
    ]).animate(AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat());

    // 링크 날아들기
    _linkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _linkX = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _linkCtrl, curve: Curves.easeIn));
    _linkOpacity = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _linkCtrl, curve: const Interval(0.7, 1.0)));
  }

  @override
  void didUpdateWidget(RobotLinkSwallowAnimation old) {
    super.didUpdateWidget(old);
    if (widget.animating && !old.animating) {
      _linkCtrl.forward(from: 0);
      // 입 빠르게
      _mouthCtrl.duration = const Duration(milliseconds: 250);
      Future.delayed(const Duration(milliseconds: 750), () {
        if (mounted) {
          _mouthCtrl.duration = const Duration(milliseconds: 1100);
        }
      });
    }
  }

  @override
  void dispose() {
    _mouthCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 떠있는 링크 칩
          AnimatedBuilder(
            animation: _linkCtrl,
            builder: (_, __) {
              final dx = _linkX.value * 90;
              return Positioned(
                right: dx,
                top: 18,
                child: Opacity(
                  opacity: _linkOpacity.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFF0000).withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link, size: 12, color: Color(0xFFFF0000)),
                        SizedBox(width: 4),
                        Text(
                          'youtube.com/…',
                          style: TextStyle(fontSize: 11, color: Color(0xFFFF0000)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // 로봇
          AnimatedBuilder(
            animation: Listenable.merge([_mouthCtrl, _blink]),
            builder: (_, __) => _Robot(
              mouthOpen: _mouthOpen.value,
              eyeScale: _blink.value,
            ),
          ),

          // 라벨
          Positioned(
            bottom: 6,
            child: Text(
              widget.label,
              style: IsleText.caption(color: IsleColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Robot extends StatelessWidget {
  const _Robot({required this.mouthOpen, required this.eyeScale});
  final double mouthOpen;
  final double eyeScale;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(72, 72),
      painter: _RobotPainter(mouthOpen: mouthOpen, eyeScale: eyeScale),
    );
  }
}

class _RobotPainter extends CustomPainter {
  const _RobotPainter({required this.mouthOpen, required this.eyeScale});
  final double mouthOpen;
  final double eyeScale;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final bodyPaint = Paint()..color = IsleColors.ocean700;
    final facePaint = Paint()..color = IsleColors.ocean500;
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = IsleColors.ocean900;
    final mouthPaint = Paint()
      ..color = IsleColors.ocean900
      ..style = PaintingStyle.fill;
    final antennaPaint = Paint()
      ..color = IsleColors.ocean700
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final toothPaint = Paint()..color = Colors.white;

    // 안테나
    canvas.drawLine(Offset(cx, 6), Offset(cx, 14), antennaPaint);
    canvas.drawCircle(Offset(cx, 5), 4, bodyPaint);

    // 몸통
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 6), width: 52, height: 46),
      const Radius.circular(10),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // 얼굴판
    final faceRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 2), width: 44, height: 38),
      const Radius.circular(8),
    );
    canvas.drawRRect(faceRect, facePaint);

    // 눈 (왼)
    final eyeLY = cy - 7.0;
    canvas.save();
    canvas.translate(cx - 10, eyeLY);
    canvas.scale(1, eyeScale);
    canvas.translate(-(cx - 10), -eyeLY);
    canvas.drawCircle(Offset(cx - 10, eyeLY), 7, eyePaint);
    canvas.drawCircle(Offset(cx - 9, eyeLY), 3.5, pupilPaint);
    canvas.restore();

    // 눈 (오)
    final eyeRY = cy - 7.0;
    canvas.save();
    canvas.translate(cx + 10, eyeRY);
    canvas.scale(1, eyeScale);
    canvas.translate(-(cx + 10), -eyeRY);
    canvas.drawCircle(Offset(cx + 10, eyeRY), 7, eyePaint);
    canvas.drawCircle(Offset(cx + 11, eyeRY), 3.5, pupilPaint);
    canvas.restore();

    // 입
    final mouthTop = cy + 9.0;
    final mouthHeight = 4.0 + mouthOpen * 14;
    final mouthRect = Rect.fromCenter(
      center: Offset(cx, mouthTop + mouthHeight / 2),
      width: 28,
      height: mouthHeight,
    );
    final mouthRR = RRect.fromRectAndRadius(mouthRect, const Radius.circular(4));
    canvas.drawRRect(mouthRR, mouthPaint);

    // 이빨 (입 열릴 때)
    if (mouthOpen > 0.3) {
      const toothW = 5.0;
      const toothH = 4.0;
      for (var i = 0; i < 3; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              cx - 14 + i * 9.0,
              mouthTop,
              toothW,
              toothH,
            ),
            const Radius.circular(1.5),
          ),
          toothPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RobotPainter old) =>
      old.mouthOpen != mouthOpen || old.eyeScale != eyeScale;
}
