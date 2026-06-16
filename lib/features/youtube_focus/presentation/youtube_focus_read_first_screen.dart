import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/youtube/models/youtube_focus_video.dart';
import '../../../core/youtube/youtube_focus_metadata_service.dart';
import '../../../core/youtube/youtube_limit_gate.dart';
import '../../../core/youtube/youtube_playback_access_guard.dart';
import '../../../core/youtube/youtube_focus_summary_quota_store.dart';
import '../../../core/youtube/youtube_focus_summary_service.dart';
import '../../../core/youtube/youtube_focus_time_store.dart';
import 'widgets/youtube_focus_time_saved_dialog.dart';
import 'youtube_focus_player_screen.dart';

/// Read-first — 3줄 요약 후 재생 선택
class YoutubeFocusReadFirstScreen extends StatefulWidget {
  const YoutubeFocusReadFirstScreen({super.key, required this.video});

  final YoutubeFocusVideo video;

  @override
  State<YoutubeFocusReadFirstScreen> createState() => _YoutubeFocusReadFirstScreenState();
}

class _ReadFirstPayload {
  const _ReadFirstPayload({required this.video, required this.lines});
  final YoutubeFocusVideo video;
  final List<String> lines;
}

class _YoutubeFocusReadFirstScreenState extends State<YoutubeFocusReadFirstScreen> {
  late Future<_ReadFirstPayload> _loadFuture;
  YoutubeFocusVideo? _enriched;
  bool _didPlay = false;
  bool _savedOnExit = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<_ReadFirstPayload> _load() async {
    final video = await YoutubeFocusMetadataService.enrich(widget.video);
    _enriched = video;
    final lines = await YoutubeFocusSummaryService.summarize(
      videoId: video.videoId,
      title: video.title,
      channelName: video.channelName,
    );
    return _ReadFirstPayload(video: video, lines: lines);
  }

  YoutubeFocusVideo get _activeVideo => _enriched ?? widget.video;

  Future<bool> _onWillPop() async {
    await _maybeRecordSaved();
    if (mounted && YoutubeFocusTimeStore.todaySavedSeconds > 0) {
      await showYoutubeFocusTimeSavedDialog(context);
    }
    return true;
  }

  Future<void> _maybeRecordSaved() async {
    if (_savedOnExit || _didPlay) return;
    var sec = _activeVideo.durationSeconds;
    if (sec <= 0) sec = 600;
    _savedOnExit = true;
    await YoutubeFocusTimeStore.addSavedSeconds(sec);
  }

  Future<void> _play() async {
    if (!YoutubeLimitGate.guard(context)) return;
    final deny = YoutubePlaybackAccessGuard.denyPlayback(
      videoId: _activeVideo.videoId,
      channelName: _activeVideo.channelName,
      videoTitle: _activeVideo.title,
      url: _activeVideo.watchUrl,
    );
    if (deny != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(deny)));
      }
      return;
    }
    setState(() => _didPlay = true);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => YoutubeFocusPlayerScreen(
          video: _activeVideo,
          onSessionEnd: (savedSeconds) async {
            if (savedSeconds > 0) {
              await YoutubeFocusTimeStore.addSavedSeconds(savedSeconds);
            }
          },
        ),
      ),
    );
    if (mounted && YoutubeFocusTimeStore.todaySavedSeconds > 0) {
      await showYoutubeFocusTimeSavedDialog(context);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black87;
    final hint = isDark ? Colors.white54 : Colors.black45;
    final dur = _activeVideo.durationLabel.isNotEmpty
        ? _activeVideo.durationLabel
        : '알 수 없는 길이';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop();
        if (context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: fg,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _onWillPop();
              if (context.mounted) context.pop();
            },
          ),
          actions: [
            IconButton(
              tooltip: '설정',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/youtube-focus/more'),
            ),
          ],
        ),
        body: Builder(
          builder: (context) {
            final locked = YoutubeLimitGate.lockedBody(context);
            if (locked != null) return locked;
            return FutureBuilder<_ReadFirstPayload>(
          future: _loadFuture,
          builder: (context, snap) {
            final payload = snap.data;
            final lines = payload?.lines;
            final video = payload?.video ?? _activeVideo;
            final quotaLeft = YoutubeFocusSummaryQuotaStore.remaining;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    video.title,
                    style: IsleText.title(color: fg).copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    video.channelName,
                    style: IsleText.caption(color: hint),
                  ),
                  if (quotaLeft < YoutubeFocusSummaryQuotaStore.freeDailyLimit) ...[
                    const SizedBox(height: 6),
                    Text(
                      '오늘 AI 요약 남음 $quotaLeft/${YoutubeFocusSummaryQuotaStore.freeDailyLimit}회',
                      style: IsleText.caption(color: hint),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (snap.connectionState != ConnectionState.done)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ))
                  else
                    ...List.generate(
                      (lines ?? []).length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}.',
                              style: IsleText.subtitle(color: hint),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                lines![i],
                                style: IsleText.body(color: fg).copyWith(
                                  fontSize: 17,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    '이 영상은 $dur 짜리입니다. 위 요약본을 읽고도 정말 시간을 투자할 가치가 있다고 '
                    '생각하시면 아래 「영상 재생」을 누르세요.',
                    style: IsleText.caption(color: hint).copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: IsleSize.minTouchTarget,
                    child: FilledButton.icon(
                      onPressed: snap.connectionState == ConnectionState.done ? _play : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('영상 재생'),
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      await _maybeRecordSaved();
                      if (context.mounted) {
                        if (YoutubeFocusTimeStore.todaySavedSeconds > 0) {
                          await showYoutubeFocusTimeSavedDialog(context);
                        }
                        if (context.mounted) context.pop();
                      }
                    },
                    child: Text(
                      '요약만 보고 나가기 (시간 아끼기)',
                      style: IsleText.caption(color: hint),
                    ),
                  ),
                ],
              ),
            );
          },
        );
          },
        ),
      ),
    );
  }
}
