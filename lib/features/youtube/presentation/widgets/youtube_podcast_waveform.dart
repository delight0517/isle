import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_typography.dart';

/// WebView 오디오 분석기에서 받은 샘플(0~1) — 대칭 막대 파형
class YoutubePodcastWaveformVisualizer extends StatelessWidget {
  const YoutubePodcastWaveformVisualizer({
    super.key,
    required this.samples,
    this.active = true,
    this.height = 72,
  });

  final List<double> samples;
  final bool active;
  final double height;

  static const _barCount = 40;
  static const _accent = Color(0xFF1DB954);
  static const _accentDim = Color(0xFF169B46);

  @override
  Widget build(BuildContext context) {
    final data = _normalize(samples);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _WaveformPainter(
            samples: data,
            active: active,
            accent: _accent,
            accentDim: _accentDim,
          ),
        ),
      ),
    );
  }

  List<double> _normalize(List<double> raw) {
    if (raw.length == _barCount) return raw;
    if (raw.isEmpty) return List.filled(_barCount, 0.06);
    final out = List<double>.filled(_barCount, 0.06);
    for (var i = 0; i < _barCount; i++) {
      final src = (i * raw.length / _barCount).floor().clamp(0, raw.length - 1);
      out[i] = raw[src].clamp(0.0, 1.0);
    }
    return out;
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.samples,
    required this.active,
    required this.accent,
    required this.accentDim,
  });

  final List<double> samples;
  final bool active;
  final Color accent;
  final Color accentDim;

  @override
  void paint(Canvas canvas, Size size) {
    final n = samples.length;
    if (n == 0) return;

    final slot = size.width / n;
    final barW = slot * 0.42;
    final midY = size.height / 2;

    for (var i = 0; i < n; i++) {
      final amp = active ? samples[i] : 0.05 + math.sin(i * 0.35) * 0.02;
      final h = (amp * size.height * 0.88).clamp(3.0, size.height);
      final cx = i * slot + slot / 2;
      final t = n > 1 ? i / (n - 1) : 0.0;
      final color = Color.lerp(accentDim, accent, 0.35 + t * 0.65)!;

      final rect = Rect.fromCenter(center: Offset(cx, midY), width: barW, height: h);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.45),
          ],
        ).createShader(rect);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barW / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.active != active || old.samples != samples;
}

/// 플레이어 상단 — 정사각 앨범아트
class YoutubePodcastAlbumHero extends StatelessWidget {
  const YoutubePodcastAlbumHero({
    super.key,
    required this.thumbnailUrl,
    this.fallback,
    this.size = 240,
  });

  final String? thumbnailUrl;
  final Widget? fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1DB954).withValues(alpha: 0.22),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: thumbnailUrl != null
            ? Image.network(
                thumbnailUrl!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => fallback ?? _defaultFallback(),
              )
            : fallback ?? _defaultFallback(),
      ),
    );
  }

  Widget _defaultFallback() {
    return Container(
      color: const Color(0xFF161616),
      child: const Center(
        child: Icon(Icons.album_outlined, size: 88, color: Color(0xFF1DB954)),
      ),
    );
  }
}

class YoutubePodcastPlayerCard extends StatelessWidget {
  const YoutubePodcastPlayerCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E1E), Color(0xFF121212), Color(0xFF0A0A0A)],
        ),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class YoutubePodcastAudioBadge extends StatelessWidget {
  const YoutubePodcastAudioBadge({super.key, required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1DB954).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1DB954).withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            playing ? Icons.graphic_eq : Icons.pause_circle_outline,
            size: 14,
            color: const Color(0xFF1DB954),
          ),
          const SizedBox(width: 6),
          Text(
            playing ? '오디오 재생 중' : '일시정지',
            style: IsleText.caption(color: const Color(0xFF1DB954))
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
