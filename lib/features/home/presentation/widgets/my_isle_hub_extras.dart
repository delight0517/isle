import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/focus/kakao_shorts_preset_service.dart';
import '../../../../core/library/models/library_entry.dart';
import '../../../../core/library/personal_library_store.dart'; // personalLibraryProvider
import '../../../../core/library/youtube_library_service.dart';
import '../../../../core/navigation/schedule_overlay_navigation.dart';
import '../../../../core/platform/isle_apple_platform.dart';
import '../../../../core/library/platform_watch_limit_store.dart';
import '../../../../core/youtube/youtube_watch_timer_store.dart';

/// 나의 Isle — YouTube 나중에 볼 + 시청 시간 + 카카오 5분 리필 프로모
class MyIsleWatchLaterCard extends ConsumerStatefulWidget {
  const MyIsleWatchLaterCard({super.key});

  @override
  ConsumerState<MyIsleWatchLaterCard> createState() =>
      _MyIsleWatchLaterCardState();
}

class _MyIsleWatchLaterCardState extends ConsumerState<MyIsleWatchLaterCard> {
  List<LibraryEntry> _watchLater(List<LibraryEntry> all) =>
      all.where((e) => e.origin == 'watch_later').toList();

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(personalLibraryProvider);
    final wl = _watchLater(all);
    final loggedIn = YoutubeLibraryService.currentAccount != null;
    final preview = wl.take(3).toList();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: const Color(0xFFFF0000).withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.watch_later_outlined,
                    color: Color(0xFFFF0000)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('YouTube 나중에 볼',
                      style: IsleText.subtitle(color: IsleColors.ocean900)),
                ),
                if (wl.isNotEmpty)
                  Chip(
                    label: Text('${wl.length}', style: IsleText.caption()),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: IsleColors.ocean100,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'YouTube 공식 API는 Watch Later 가져오기를 지원하지 않아요. 아래에서 YouTube 앱/웹으로 열 수 있고, 기존에 저장한 항목은 여기서 계속 볼 수 있어요.',
              style: IsleText.caption(color: IsleColors.muted)
                  .copyWith(height: 1.35),
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...preview.map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.play_circle_outline,
                      size: 20, color: Color(0xFFFF0000)),
                  title: Text(
                    e.title.isNotEmpty ? e.title : '제목 없음',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IsleText.body(),
                  ),
                  onTap: e.url.isEmpty
                      ? null
                      : () => context.push(
                            '/youtube/browser?url=${Uri.encodeComponent(e.url)}',
                          ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0000),
                      minimumSize:
                          const Size.fromHeight(IsleSize.minTouchTarget),
                    ),
                    icon: const Icon(Icons.info_outline),
                    label: const Text('자동 가져오기 미지원'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: '유튜브에서 열기',
                  onPressed: () => context.push(
                    '/youtube/browser?url=${Uri.encodeComponent('https://m.youtube.com/playlist?list=WL')}',
                  ),
                  icon: const Icon(Icons.open_in_new),
                ),
              ],
            ),
            if (!loggedIn)
              TextButton(
                onPressed: () => context.push('/settings/youtube-account-sync'),
                child: const Text('YouTube 계정 연결'),
              ),
          ],
        ),
      ),
    );
  }
}

/// 유튜브 시청 한도 — 한 줄 상태 + 관리 진입
class MyIsleYoutubeTimeCard extends StatelessWidget {
  const MyIsleYoutubeTimeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final on = YoutubeWatchTimerStore.isEnabled;
    final status = YoutubeWatchTimerStore.formatStatusLine();

    return Card(
      elevation: 0,
      color: on ? IsleColors.ocean100 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: on
                ? IsleColors.ocean500
                : IsleColors.muted.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/home/my-isle/manage'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.lock_clock,
                  color: on ? IsleColors.ocean700 : IsleColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('유튜브 시청 시간',
                        style: IsleText.subtitle(color: IsleColors.ocean900)),
                    const SizedBox(height: 4),
                    Text(status,
                        style: IsleText.caption(color: IsleColors.muted)),
                  ],
                ),
              ),
              Icon(
                on ? Icons.check_circle : Icons.chevron_right,
                color: on ? IsleColors.ocean500 : IsleColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Instagram 피드 한도 — DM은 무제한
class MyIsleInstagramTimeCard extends StatelessWidget {
  const MyIsleInstagramTimeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final on = PlatformWatchLimitStore.isEnabled(PlatformWatchId.instagram);
    final chip =
        PlatformWatchLimitStore.formatRemainChip(PlatformWatchId.instagram);
    final used =
        PlatformWatchLimitStore.secondsUsedToday(PlatformWatchId.instagram);
    final limit =
        PlatformWatchLimitStore.limitSeconds(PlatformWatchId.instagram);

    return Card(
      elevation: 0,
      color: on ? const Color(0xFFFCE4EC) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: on
              ? const Color(0xFFE1306C).withValues(alpha: 0.35)
              : IsleColors.muted.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/settings/instagram-limits?scope=feed'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.camera_alt_outlined,
                  color: on ? const Color(0xFFE1306C) : IsleColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Instagram 피드',
                        style: IsleText.subtitle(color: IsleColors.ocean900)),
                    const SizedBox(height: 4),
                    Text(
                      on
                          ? '$chip · ${used ~/ 60}/${limit ~/ 60}분 · DM 무제한'
                          : '한도 끔 · DM 무제한',
                      style: IsleText.caption(color: IsleColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: IsleColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카카오톡 5분 리필 — 노란 카드뉴스 스타일 발견용 배너
class KakaoFreezePromoCard extends StatefulWidget {
  const KakaoFreezePromoCard({super.key});

  @override
  State<KakaoFreezePromoCard> createState() => _KakaoFreezePromoCardState();
}

class _KakaoFreezePromoCardState extends State<KakaoFreezePromoCard> {
  static const _kakaoYellow = Color(0xFFFEE500);
  static const _kakaoBrown = Color(0xFF3B1E1E);
  bool _busy = false;

  Future<void> _applyRefill() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await KakaoShortsPresetService.applyMicroRefillSchedule();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              result.statusMessage(isIos: IsleApplePlatform.isScreenTimeHost)),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: '설정',
            onPressed: () => pushBlockScheduleEdit(context, result.schedule.id),
          ),
        ),
      );
      if (result.needsScreenTimePick && IsleApplePlatform.isNativeBlockHost) {
        pushBlockScheduleEdit(context, result.schedule.id);
      } else if (Platform.isAndroid) {
        context.push('/home/block/pomodoro?tab=refill');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kakaoYellow,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: _busy ? null : _applyRefill,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kakaoBrown,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '카카오톡 사용 시간 관리',
                      style: IsleText.caption(color: _kakaoYellow).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chat_bubble,
                      color: _kakaoBrown.withValues(alpha: 0.85), size: 28),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                IsleApplePlatform.isScreenTimeHost
                    ? '매시간 5분만 카카오톡'
                    : '5분마다 3분만 카카오톡',
                style: IsleText.subtitle(color: _kakaoBrown)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '앱을 쓸 때만 카운트 · 릴스·쇼츠 확인을 끊는 가장 쉬운 방법',
                style:
                    IsleText.caption(color: _kakaoBrown.withValues(alpha: 0.75))
                        .copyWith(height: 1.35),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: IsleSize.minTouchTarget,
                child: FilledButton(
                  onPressed: _busy ? null : _applyRefill,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kakaoBrown,
                    foregroundColor: _kakaoYellow,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _kakaoYellow),
                        )
                      : const Text('지금 켜기 — 5분 리필'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
