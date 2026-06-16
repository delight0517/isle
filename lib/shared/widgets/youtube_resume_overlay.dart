import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/isle_navigation.dart';
import '../../core/constants/app_typography.dart';
import '../../core/youtube/youtube_limit_gate.dart';
import '../../core/youtube/youtube_session.dart';

/// 피드·다른 탭 — 「다시 보기」 / 아래로 드래그해 종료
class YoutubeResumeOverlay extends StatefulWidget {
  const YoutubeResumeOverlay({super.key});

  @override
  State<YoutubeResumeOverlay> createState() => _YoutubeResumeOverlayState();
}

class _YoutubeResumeOverlayState extends State<YoutubeResumeOverlay> {
  double _dragDy = 0;
  bool _overTrash = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: YoutubeSession.instance,
      builder: (_, __) {
        final s = YoutubeSession.instance;
        if (!s.hasParkedSession) return const SizedBox.shrink();

        final bottom = MediaQuery.paddingOf(context).bottom;
        final title = s.probed.videoTitle.isNotEmpty
            ? s.probed.videoTitle
            : (s.displayTitle.isNotEmpty ? s.displayTitle : '유튜브');

        return Positioned(
          left: 12,
          right: 12,
          bottom: bottom + 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_dragDy > 40)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _overTrash ? IsleColors.danger : Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: _overTrash ? Colors.white : Colors.white70,
                    size: 28,
                  ),
                ),
              if (_dragDy > 40) const SizedBox(height: 8),
              GestureDetector(
                onVerticalDragUpdate: (d) {
                  setState(() {
                    _dragDy += d.delta.dy;
                    _overTrash = _dragDy > 72;
                  });
                },
                onVerticalDragEnd: (_) {
                  if (_overTrash) {
                    HapticFeedback.heavyImpact();
                    YoutubeSession.instance.quit();
                  }
                  setState(() {
                    _dragDy = 0;
                    _overTrash = false;
                  });
                },
                child: Transform.translate(
                  offset: Offset(0, _dragDy.clamp(0, 120)),
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF1A1A1A),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        if (!YoutubeLimitGate.guard(context)) return;
                        HapticFeedback.mediumImpact();
                        final ok = IsleNavigation.push('/youtube/browser', from: context);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('유튜브 화면을 열 수 없어요. 앱을 다시 실행해 주세요.')),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF0000).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.play_circle_filled,
                                color: Color(0xFFFF0000),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '다시 보기',
                                    style: IsleText.caption(color: IsleColors.gold500)
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    title,
                                    style: IsleText.body(color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white54, size: 22),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                YoutubeSession.instance.quit();
                              },
                              tooltip: '유튜브 끄기',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '탭: 다시 보기 · 아래로 드래그: 종료',
                style: IsleText.caption(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
