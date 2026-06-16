import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/ai/ai_client.dart';
import '../../../core/library/brunch_profile_fetcher.dart';
import '../../../core/library/digest_scheduler.dart';
import '../../../core/library/models/connected_source.dart';
import '../../../core/library/personal_library_store.dart';
import '../../../core/library/watch_later_curator_service.dart';
import '../../../core/library/youtube_account_sync_service.dart';
import '../../../core/library/youtube_library_service.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/services/setup_journey_service.dart';
import '../../feed/presentation/widgets/youtube_channel_search_sheet.dart';
import '../../feed/providers/feed_provider.dart';

/// 유튜브·브런치 등 출처 연결 — 수동 가져오기 (자동 클라우드 동기화 없음)
class MySourcesScreen extends ConsumerStatefulWidget {
  const MySourcesScreen({super.key});

  @override
  ConsumerState<MySourcesScreen> createState() => _MySourcesScreenState();
}

class _MySourcesScreenState extends ConsumerState<MySourcesScreen> {
  final _brunchCtrl = TextEditingController(text: 'https://brunch.co.kr/@rogan2534');
  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _brunchCtrl.dispose();
    super.dispose();
  }

  Future<void> _setBusy(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await fn();
    } catch (e) {
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (!YoutubeLibraryService.canAttemptSignIn) {
      await _showGoogleSetupDialog();
      return;
    }
    await _setBusy(() async {
      final result = await YoutubeLibraryService.signIn();
      if (!mounted) return;
      if (result.success) {
        final sync = await YoutubeAccountSyncService.syncNow(force: true);
        await ref.read(personalLibraryProvider.notifier).reload();
        ref.invalidate(feedProvider);
        setState(() {
          _status = result.email != null
              ? '${result.email} 로그인 · 동기화 +${sync.totalNew}'
              : '로그인 · 동기화 +${sync.totalNew}';
        });
      } else if (result.needsConfiguration) {
        await _showGoogleSetupDialog();
      } else {
        setState(() => _status = result.message ?? '로그인 실패');
      }
      setState(() {});
    });
  }

  Future<void> _showGoogleSetupDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Google 로그인 설정', style: IsleText.subtitle()),
        content: SingleChildScrollView(
          child: Text(
            '${YoutubeLibraryService.setupHint}\n\n'
            '설정 전에는 로그인 버튼을 눌러도 앱이 종료될 수 있어요. '
            'WebView 로그인은 시청용이고, 「나중에 볼」 가져오기는 위 OAuth 설정이 필요합니다.',
            style: IsleText.body(color: IsleColors.muted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/youtube/login-guide');
            },
            child: const Text('WebView 로그인 안내'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(connectedSourcesProvider);
    final library = ref.watch(personalLibraryProvider);
    final ytAccount = YoutubeLibraryService.currentAccount;
    final googleReady = YoutubeLibraryService.canAttemptSignIn;

    return Scaffold(
      appBar: AppBar(
        title: Text('내 콘텐츠', style: IsleText.subtitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_fill, color: Color(0xFFFF0000)),
            tooltip: '유튜브 바로 보기',
            onPressed: () => context.push('/youtube/browser'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [IsleColors.ocean900, IsleColors.ocean500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('피드를 채우는 첫걸음', style: IsleText.subtitle(color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  '가져온 콘텐츠만 피드·내 섬에 반영됩니다. 서버에 자동 동기화하지 않아요.',
                  style: IsleText.caption(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: SetupJourneyService.progress.clamp(0.08, 1.0),
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(IsleColors.gold500),
                ),
              ],
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(_status!, style: IsleText.caption(color: IsleColors.ocean900)),
          ],
          if (!googleReady) ...[
            const SizedBox(height: 12),
            Material(
              color: IsleColors.gold300.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _showGoogleSetupDialog,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: IsleColors.sand900),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Google 로그인: 개발자 설정 필요 (탭하여 안내)',
                          style: IsleText.caption(color: IsleColors.sand900),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: IsleColors.sand900),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _sectionTitle('YouTube'),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => showYoutubeChannelSearchSheet(context, ref),
            icon: const Icon(Icons.search, color: Color(0xFFFF0000)),
            label: const Text('여러 유튜버들 검색하기! · 구독 추가'),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              ytAccount?.email ?? (googleReady ? 'Google로 로그인 (나중에 볼)' : 'Google 로그인 (설정 필요)'),
            ),
            subtitle: Text(
              googleReady
                  ? '자동 동기화·플레이리스트 — 설정에서 관리'
                  : 'OAuth clientId + Info.plist URL scheme',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            onTap: googleReady ? () => context.push('/settings/youtube-account-sync') : null,
            trailing: ytAccount == null
                ? FilledButton(
                    onPressed: _busy ? null : _onGoogleSignIn,
                    child: Text(googleReady ? '로그인' : '설정 안내'),
                  )
                : TextButton(
                    onPressed: _busy
                        ? null
                        : () => _setBusy(() async {
                              await YoutubeLibraryService.signOut();
                              setState(() => _status = '로그아웃됨');
                            }),
                    child: const Text('로그아웃'),
                  ),
          ),
          FilledButton.icon(
            onPressed: _busy || ytAccount == null
                ? null
                : () => _setBusy(() async {
                      final items = await YoutubeLibraryService.fetchWatchLater();
                      final n = await ref.read(personalLibraryProvider.notifier).merge(items);
                      await SetupJourneyService.markStepDone('import_content');
                      setState(() => _status = '나중에 볼 ${items.length}개 중 $n개 새로 추가');
                      ref.invalidate(feedProvider);
                    }),
            icon: const Icon(Icons.playlist_play),
            label: const Text('나중에 볼 목록 가져오기'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _setBusy(() async {
                      final n = await WatchLaterCuratorService.buildCuratedSuggestions(
                        newestFraction: 0.3,
                      );
                      await SetupJourneyService.markStepDone('import_content');
                      setState(() => _status = '나중에 볼 기반 추천 카드 $n개 생성 (최신 30%)');
                      ref.invalidate(feedProvider);
                    }),
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('나중에 볼 → 피드 추천 (로컬)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy || ytAccount == null
                ? null
                : () => _setBusy(() async {
                      final items = await YoutubeLibraryService.fetchSubscriptionFeed();
                      final n = await ref.read(personalLibraryProvider.notifier).merge(items);
                      await SetupJourneyService.markStepDone('import_content');
                      setState(() => _status = '구독 채널 영상 ${items.length}개 · $n개 새로 추가');
                      ref.invalidate(feedProvider);
                    }),
            icon: const Icon(Icons.subscriptions_outlined),
            label: const Text('구독 채널 새 영상 가져오기'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('앱 안에서 본 영상 → 피드에 기록'),
            subtitle: const Text('유튜브 WebView 시청 시 자동'),
            value: IsleUserDefaults.trackYoutubeWatchHistory,
            onChanged: _busy
                ? null
                : (v) async {
                    await IsleUserDefaults.setTrackYoutubeWatchHistory(v);
                    setState(() {});
                  },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/youtube/login-guide'),
            icon: const Icon(Icons.login),
            label: const Text('WebView 로그인 (앱 안에서 시청)'),
          ),
          const SizedBox(height: 24),
          _sectionTitle('브런치'),
          TextField(
            controller: _brunchCtrl,
            decoration: const InputDecoration(
              labelText: '프로필 URL',
              hintText: 'https://brunch.co.kr/@handle',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _setBusy(() async {
                      final url = BrunchProfileFetcher.normalizeProfileUrl(_brunchCtrl.text);
                      if (url == null) {
                        setState(() => _status = '브런치 프로필 URL을 확인하세요');
                        return;
                      }
                      final handle = BrunchProfileFetcher.handleFromUrl(url);
                      await ref.read(connectedSourcesProvider.notifier).add(
                            ConnectedSource(
                              id: 'br_${handle}_${DateTime.now().millisecondsSinceEpoch}',
                              type: 'brunch',
                              profileUrl: url,
                              displayName: handle,
                              addedAt: DateTime.now(),
                            ),
                          );
                      final articles = await BrunchProfileFetcher.fetchArticles(url);
                      final n = await ref.read(personalLibraryProvider.notifier).merge(articles);
                      await SetupJourneyService.markStepDone('import_content');
                      for (final src in ref.read(connectedSourcesProvider)) {
                        if (src.profileUrl == url) {
                          await ref.read(connectedSourcesProvider.notifier).markSynced(src.id);
                          break;
                        }
                      }
                      setState(() => _status = '브런치 ${articles.length}편 · $n개 새로 추가');
                      ref.invalidate(feedProvider);
                    }),
            icon: const Icon(Icons.article_outlined),
            label: const Text('브런치 글 가져오기'),
          ),
          const SizedBox(height: 24),
          _sectionTitle('요약 뉴스 카드'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('시청·가져온 콘텐츠를 요약 카드로'),
            subtitle: Text(
              '주 ${IsleUserDefaults.digestMaxPerWeek}회까지 · ${AiClient.isConfigured ? 'AI 요약' : '로컬 요약'}',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            value: IsleUserDefaults.digestToFeedEnabled,
            onChanged: _busy
                ? null
                : (v) async {
                    await IsleUserDefaults.setDigestToFeedEnabled(v);
                    setState(() {});
                  },
          ),
          Row(
            children: [
              const Text('주당 최대'),
              Expanded(
                child: Slider(
                  value: IsleUserDefaults.digestMaxPerWeek.toDouble(),
                  min: 1,
                  max: 7,
                  divisions: 6,
                  label: '${IsleUserDefaults.digestMaxPerWeek}',
                  onChanged: _busy
                      ? null
                      : (v) async {
                          await IsleUserDefaults.setDigestMaxPerWeek(v.round());
                          setState(() {});
                        },
                ),
              ),
              Text('${IsleUserDefaults.digestMaxPerWeek}회'),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _busy || !IsleUserDefaults.digestToFeedEnabled
                ? null
                : () => _setBusy(() async {
                      final n = await DigestScheduler.runIfAllowed();
                      ref.invalidate(feedProvider);
                      await ref.read(personalLibraryProvider.notifier).reload();
                      setState(() => _status = n > 0 ? '요약 카드 $n개 생성' : '이번 주 한도이거나 대상 없음');
                    }),
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text('지금 요약 만들기'),
          ),
          const SizedBox(height: 24),
          _sectionTitle('연결된 출처 (${sources.length})'),
          if (sources.isEmpty)
            Text('아직 없음', style: IsleText.body(color: IsleColors.muted))
          else
            ...sources.map(
              (s) => ListTile(
                title: Text(s.displayName.isEmpty ? s.profileUrl : s.displayName),
                subtitle: Text('${s.type} · ${s.lastSyncedAt != null ? '동기화됨' : '미동기화'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref.read(connectedSourcesProvider.notifier).remove(s.id),
                ),
              ),
            ),
          const SizedBox(height: 16),
          _sectionTitle('라이브러리 (${library.length}개)'),
          Text(
            '피드·검색에 합쳐집니다. 탭하면 원문으로 이동합니다.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 8),
          if (library.isEmpty)
            Text('가져오기 버튼을 눌러 콘텐츠를 추가하세요.', style: IsleText.body(color: IsleColors.muted))
          else
            ...library.take(40).map((e) {
              final originLabel = switch (e.origin) {
                'watch_later' => '나중에 볼',
                'brunch_sync' => '브런치',
                'youtube_history' => '시청 기록',
                'subscription' => '구독',
                _ => e.origin,
              };
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: e.thumbnailUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(e.thumbnailUrl, width: 56, height: 56, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.article_outlined)),
                      )
                    : const Icon(Icons.article_outlined),
                title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: IsleText.body()),
                subtitle: Text('$originLabel · ${e.channelName.isNotEmpty ? e.channelName : e.sourceType}',
                    style: IsleText.caption(color: IsleColors.muted)),
                trailing: e.summary != null ? const Icon(Icons.auto_stories, size: 18) : null,
                onTap: () => context.push(
                  '/viewer?url=${Uri.encodeComponent(e.url)}&title=${Uri.encodeComponent(e.title)}',
                ),
              );
            }),
          if (library.length > 40)
            Text('외 ${library.length - 40}개…', style: IsleText.caption(color: IsleColors.muted)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => ref.invalidate(feedProvider),
            child: const Text('피드 새로고침'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: IsleText.subtitle()),
      );
}
