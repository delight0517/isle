import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/library/models/youtube_playlist_summary.dart';
import '../../../core/library/personal_library_store.dart';
import '../../../core/library/youtube_account_sync_service.dart';
import '../../../core/library/youtube_library_service.dart';
import '../../../core/services/isle_error_feedback.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../feed/providers/feed_provider.dart';

/// 내 Google/YouTube 계정 — 로그인 · 나중에 볼 · 플레이리스트 자동 동기화
class YoutubeAccountSyncScreen extends ConsumerStatefulWidget {
  const YoutubeAccountSyncScreen({super.key});

  @override
  ConsumerState<YoutubeAccountSyncScreen> createState() =>
      _YoutubeAccountSyncScreenState();
}

class _YoutubeAccountSyncScreenState
    extends ConsumerState<YoutubeAccountSyncScreen> {
  bool _busy = false;
  String? _status;
  bool _auto = IsleUserDefaults.youtubeAccountAutoSync;
  List<YoutubePlaylistSummary> _playlists = const [];
  Set<String> _selectedPlaylistIds = {
    ...IsleUserDefaults.youtubeSyncPlaylistIds
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadPlaylistsIfSignedIn());
  }

  Future<void> _loadPlaylistsIfSignedIn() async {
    if (YoutubeLibraryService.currentAccount == null) return;
    try {
      final list = await YoutubeLibraryService.fetchMyPlaylists();
      if (!mounted) return;
      setState(() => _playlists = list);
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _status = IsleErrorFeedback.friendly(e));
      IsleErrorFeedback.log('youtube_account_playlists', e, stack: st);
    }
  }

  Future<void> _runBusy(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    if (!YoutubeLibraryService.canAttemptSignIn) {
      setState(() => _status = YoutubeLibraryService.setupHint);
      return;
    }
    await _runBusy(() async {
      final r = await YoutubeLibraryService.signIn();
      if (!r.success) {
        setState(() => _status = r.message ?? '로그인 실패');
        return;
      }
      await _loadPlaylistsIfSignedIn();
      final sync = await YoutubeAccountSyncService.syncNow(force: true);
      await ref.read(personalLibraryProvider.notifier).reload();
      ref.invalidate(feedProvider);
      setState(() {
        _status = _formatSyncResult(sync, prefix: '로그인 후 동기화 · ');
      });
    });
  }

  Future<void> _signOut() async {
    await _runBusy(() async {
      await YoutubeLibraryService.signOut();
      setState(() {
        _playlists = const [];
        _selectedPlaylistIds = {};
        _status = '로그아웃됨';
      });
    });
  }

  Future<void> _syncNow() async {
    await _runBusy(() async {
      final sync = await YoutubeAccountSyncService.syncNow(force: true);
      await ref.read(personalLibraryProvider.notifier).reload();
      ref.invalidate(feedProvider);
      setState(() => _status = _formatSyncResult(sync));
    });
  }

  String _formatSyncResult(YoutubeAccountSyncResult r, {String prefix = ''}) {
    if (r.skipped) return '$prefix${r.message ?? ''}';
    if (r.message != null && r.totalNew == 0 && r.playlistVideosCount == 0) {
      return '$prefix${r.message}';
    }
    return '$prefix플레이리스트 ${r.playlistVideosCount}개 (새 ${r.playlistVideosNew})'
        '${r.message == null ? '' : ' · ${r.message}'}';
  }

  String? _lastSyncLabel() {
    final ms = IsleUserDefaults.youtubeLastAccountSyncMs;
    if (ms == null) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(ms);
    final local = at.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportWatchLaterJson() async {
    final entries = PersonalLibraryStore.loadEntries()
        .where((e) => e.origin == 'watch_later')
        .toList();
    final payload = entries.map((e) => e.toJson()).toList();
    final text = const JsonEncoder.withIndent('  ').convert(payload);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('나중에 볼 ${entries.length}개 JSON을 클립보드에 복사했어요')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = YoutubeLibraryService.currentAccount;
    final wlCount = YoutubeAccountSyncService.watchLaterInLibraryCount();
    final lastSync = _lastSyncLabel();

    return Scaffold(
      appBar: AppBar(
        title: Text('YouTube 계정 동기화', style: IsleText.subtitle()),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          IsleSize.screenPadding,
          IsleSize.screenPadding,
          IsleSize.screenPadding,
          IsleSize.scrollBottomPadding(context),
        ),
        children: [
          Card(
            color: IsleColors.ocean100.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('내 계정의 지원 목록 연결',
                      style: IsleText.subtitle(color: IsleColors.ocean900)),
                  const SizedBox(height: 8),
                  Text(
                    'Google로 로그인하면 선택한 일반 플레이리스트 항목을 MOA에 저장해요. '
                    'Watch Later와 계정 전체 시청 기록은 공식 API에서 제공되지 않습니다.',
                    style: IsleText.body(color: IsleColors.muted)
                        .copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(account?.email ?? '로그인 안 됨', style: IsleText.body()),
            subtitle: Text(
              account != null
                  ? '이 계정의 선택한 일반 플레이리스트를 가져옵니다'
                  : YoutubeLibraryService.setupHint,
              style: IsleText.caption(color: IsleColors.muted),
            ),
            trailing: account == null
                ? FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: const Text('Google 로그인'),
                  )
                : TextButton(
                    onPressed: _busy ? null : _signOut,
                    child: const Text('로그아웃')),
          ),
          if (account != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _statChip('저장된 Watch Later 항목', '$wlCount개'),
                const SizedBox(width: 8),
                if (lastSync != null) _statChip('마지막 동기화', lastSync),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: IsleSize.minTouchTarget,
              child: FilledButton.icon(
                onPressed: _busy ? null : _syncNow,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync),
                label: const Text('지금 동기화'),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('자동 동기화 (앱 복귀 시, 3시간 간격)', style: IsleText.body()),
              subtitle: Text(
                '앱을 다시 열었을 때 마지막 동기화가 3시간 이상 지났으면 가져옵니다. iOS가 앱을 닫은 동안 실행하는 백그라운드 동기화는 아닙니다.',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              value: _auto,
              onChanged: _busy
                  ? null
                  : (v) async {
                      await IsleUserDefaults.setYoutubeAccountAutoSync(v);
                      setState(() => _auto = v);
                    },
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Watch Later와 YouTube 계정 전체 시청 기록은 공식 YouTube API에서 제공되지 않아 자동 가져오기를 할 수 없어요. MOA 안에서 재생한 시청 기록은 이 기기에 자동 저장됩니다.',
                  style: IsleText.caption(color: IsleColors.muted)
                      .copyWith(height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: wlCount == 0 ? null : _exportWatchLaterJson,
              icon: const Icon(Icons.copy),
              label: const Text('나중에 볼 데이터 JSON 복사'),
            ),
            const SizedBox(height: 20),
            Text('동기화할 일반 플레이리스트', style: IsleText.subtitle()),
            const SizedBox(height: 6),
            Text(
              '체크한 일반 목록의 영상이 「내 콘텐츠」에 쌓입니다.',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            const SizedBox(height: 8),
            if (_playlists.isEmpty)
              Text(
                _busy ? '목록 불러오는 중…' : '플레이리스트가 없거나 불러오지 못했어요.',
                style: IsleText.caption(color: IsleColors.muted),
              )
            else
              ..._playlists.where((p) => !p.isWatchLater).map((p) {
                final on = _selectedPlaylistIds.contains(p.id);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: on,
                  onChanged: _busy
                      ? null
                      : (v) async {
                          final next = {..._selectedPlaylistIds};
                          if (v == true) {
                            next.add(p.id);
                          } else {
                            next.remove(p.id);
                          }
                          await IsleUserDefaults.setYoutubeSyncPlaylistIds(
                              next.toList());
                          setState(() => _selectedPlaylistIds = next);
                        },
                  title: Text(p.title, style: IsleText.body()),
                  subtitle: Text(
                    '${p.itemCount}개 · ${p.privacyStatus ?? 'unknown'}',
                    style: IsleText.caption(color: IsleColors.muted),
                  ),
                  secondary:
                      const Icon(Icons.playlist_play, color: Color(0xFFFF0000)),
                );
              }),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/library/sources'),
              icon: const Icon(Icons.library_books_outlined),
              label: const Text('내 콘텐츠에서 보기'),
            ),
          ],
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!, style: IsleText.caption(color: IsleColors.ocean700)),
          ],
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: IsleColors.sand100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IsleColors.ocean100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: IsleText.caption(color: IsleColors.muted)),
            Text(value,
                style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
