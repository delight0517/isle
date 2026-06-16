import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';

/// 안드로이드 교육 튜토리얼 — 텍스트 최소·그림 최대
class AndroidTutorialDiagrams {
  AndroidTutorialDiagrams._();

  static Widget islandMetaphor() {
    return SizedBox(
      height: 200,
      child: CustomPaint(
        painter: _IslandMetaphorPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '폭풍 바다 = 알고리즘·SNS',
                style: IsleText.caption(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: IsleColors.gold500.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.landscape_rounded, color: IsleColors.ocean900, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'Isle = 내가 고른 콘텐츠만',
                      style: IsleText.subtitle(color: IsleColors.ocean900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget feedCardsPreview() {
    return Column(
      children: [
        _fakeFeedCard(
          color: IsleColors.ocean100,
          title: '내 관심사 영상',
          channel: '구독 채널',
          icon: Icons.favorite_border,
        ),
        const SizedBox(height: 8),
        _fakeFeedCard(
          color: const Color(0xFFFFEBEE),
          title: '시청했던 주제',
          channel: '자동 추천',
          icon: Icons.history,
        ),
        const SizedBox(height: 8),
        _fakeFeedCard(
          color: IsleColors.sand100,
          title: '이런 거 그만',
          channel: '길게 눌러 차단',
          icon: Icons.block,
          muted: true,
        ),
      ],
    );
  }

  static Widget youtubeFlow() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Row(
        children: [
          _flowNode(Icons.language, 'Chrome\n유튜브', muted: true, strike: true),
          _flowArrow(),
          _flowNode(Icons.sailing, 'Isle\n가운데 탭', accent: true, youtube: true),
          _flowArrow(),
          _flowNode(Icons.timer_outlined, '시간\n기록', accent: true),
        ],
      ),
    );
  }

  static Widget blockAppsFlow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _appBubble(Icons.camera_alt, '인스타', blocked: true),
        _appBubble(Icons.music_note, '틱톡', blocked: true),
        _appBubble(Icons.chat, '카톡', blocked: false),
        _shieldBadge(),
      ],
    );
  }

  static Widget bottomNavPreview() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IsleColors.ocean100, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(child: _navItem(Icons.shield, '차단', selected: false)),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: IsleColors.ocean500, width: 2),
                    color: IsleColors.ocean100,
                  ),
                  child: const Icon(Icons.play_circle, color: Color(0xFFFF0000), size: 32),
                ),
                Text('유튜브', style: IsleText.caption(color: IsleColors.ocean700)),
              ],
            ),
          ),
          Expanded(child: _navItem(Icons.inbox, '받기', selected: false)),
        ],
      ),
    );
  }

  static Widget shareToIsle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _flowNode(Icons.chat_bubble_outline, '카톡\n링크', accent: true),
          _flowArrow(),
          _flowNode(Icons.share, '공유\nIsle', accent: true),
          _flowArrow(),
          _flowNode(Icons.play_circle_fill, 'Isle\n재생', youtube: true),
        ],
      ),
    );
  }

  static Widget _fakeFeedCard({
    required Color color,
    required String title,
    required String channel,
    required IconData icon,
    bool muted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: muted ? IsleColors.muted.withValues(alpha: 0.3) : IsleColors.ocean100),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: IsleColors.ocean500, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: IsleText.body().copyWith(
                    fontWeight: FontWeight.w600,
                    color: muted ? IsleColors.muted : IsleColors.ocean900,
                  ),
                ),
                Text(channel, style: IsleText.caption(color: IsleColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _flowNode(
    IconData icon,
    String label, {
    bool muted = false,
    bool accent = false,
    bool youtube = false,
    bool strike = false,
  }) {
    final bg = muted
        ? IsleColors.sand100
        : youtube
            ? const Color(0xFFFF0000).withValues(alpha: 0.12)
            : IsleColors.ocean100;
    final fg = muted
        ? IsleColors.muted
        : youtube
            ? const Color(0xFFFF0000)
            : IsleColors.ocean700;
    return Expanded(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 22, color: fg),
              ),
              if (strike)
                Positioned.fill(
                  child: CustomPaint(painter: _StrikePainter()),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: IsleText.caption(color: fg).copyWith(fontSize: 10, height: 1.2),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static Widget _flowArrow() => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Icon(Icons.arrow_forward, size: 16, color: IsleColors.ocean300),
      );

  static Widget _appBubble(IconData icon, String label, {required bool blocked}) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: blocked ? IsleColors.danger.withValues(alpha: 0.12) : IsleColors.ocean100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: blocked ? IsleColors.danger : IsleColors.ocean300,
                  width: 2,
                ),
              ),
              child: Icon(icon, color: blocked ? IsleColors.danger : IsleColors.ocean700),
            ),
            if (blocked)
              const Positioned(
                right: -4,
                top: -4,
                child: Icon(Icons.block, color: IsleColors.danger, size: 22),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(label, style: IsleText.caption(color: IsleColors.ocean900)),
      ],
    );
  }

  static Widget _shieldBadge() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: IsleColors.ocean500,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.shield, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 6),
        Text('차단 탭', style: IsleText.caption(color: IsleColors.ocean700)),
      ],
    );
  }

  static Widget _navItem(IconData icon, String label, {required bool selected}) {
    final color = selected ? IsleColors.ocean700 : IsleColors.muted;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(label, style: IsleText.caption(color: color)),
      ],
    );
  }
}

class _IslandMetaphorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wave = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [IsleColors.ocean700, IsleColors.ocean900],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(0, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.2, size.width * 0.5, size.height * 0.38)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.55, size.width, size.height * 0.32)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, wave);

    final island = Paint()..color = IsleColors.sand100;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.62),
        width: size.width * 0.55,
        height: size.height * 0.22,
      ),
      island,
    );

    final palm = Paint()..color = IsleColors.ocean500;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.52), 6, palm);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.58),
        width: 4,
        height: 18,
      ),
      palm,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StrikePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = IsleColors.danger
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.1, size.height * 0.9), Offset(size.width * 0.9, size.height * 0.1), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
