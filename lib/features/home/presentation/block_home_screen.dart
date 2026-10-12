import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/block_schedule/block_focus_service.dart';
import '../../../core/focus/isle_product_focus.dart';
import '../../../core/block_schedule/block_suggestion_service.dart';
import '../../../core/navigation/isle_routes.dart';
import '../../../core/navigation/schedule_overlay_navigation.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/library/platform_usage_stats.dart';
import '../../../core/blocking/blocking_controller_provider.dart';
import '../../../core/platform/platform_block_intent.dart';
import '../../../core/platform/ios_screen_time_service.dart';
import '../../../core/platform/isle_apple_platform.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../shared/widgets/android_blocking_setup_checklist.dart';
import '../../../shared/widgets/blocking_capabilities_banner.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../../shared/widgets/isle_center_action_hub.dart';
import '../../../shared/widgets/isle_home_quick_strip.dart';
import 'widgets/addiction_insight_card.dart';
import 'widgets/always_on_app_block_section.dart';
import 'widgets/safari_youtube_inbound_section.dart';

import 'widgets/block_schedule_overview.dart';
import 'widgets/website_block_section.dart';

/// 홈 — 다른 앱 차단·스케줄·통계·추천을 한 화면에 통합
class BlockHomeScreen extends ConsumerStatefulWidget {
  const BlockHomeScreen({super.key});

  @override
  ConsumerState<BlockHomeScreen> createState() => _BlockHomeScreenState();
}

class _BlockHomeScreenState extends ConsumerState<BlockHomeScreen> {
  Map<String, Map<String, int>> _daily = const {};
  Map<String, int> _today = const {};
  BlockSuggestion? _suggestion;
  BlockFocusStatus? _status;
  bool _loading = true;
  bool _setupBusy = false;
  int _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowLauncherHint());
  }

  void _maybeShowLauncherHint() {
    if (IsleUserDefaults.hasSeenQuickLauncherHint || !mounted) return;
    unawaited(IsleUserDefaults.setHasSeenQuickLauncherHint(true));
    showIsleCenterActionHub(context);
  }

  Future<void> _load() async {
    final daily = await PlatformUsageStats.dailyByPlatform(days: 7);
    final today = await PlatformUsageStats.todayByPlatform();
    final suggestion = await BlockSuggestionService.nextSuggestion();
    final status = await BlockFocusService.loadStatus();
    if (!mounted) return;
    setState(() {
      _daily = daily;
      _today = today;
      _suggestion = suggestion;
      _status = status;
      _loading = false;
      _refreshToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    return Scaffold(
      backgroundColor: IsleColors.sand100,
      appBar: IsleAppBar(
        title: '차단',
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: '차단 AI 챗',
            onPressed: () => context.push('/settings/block-chat'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '고급 설정',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/block-chat'),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('챗으로 차단'),
        backgroundColor: IsleColors.ocean500,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
          children: [
            const PrincipleBannerWidget(),
            const AddictionInsightCard(),
            const SizedBox(height: 12),
            // ── 챗 히어로 (최상단 일급 진입점) ──────────────────────
            GestureDetector(
              onTap: () => context.push('/settings/block-chat'),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.chat_bubble_outline,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('차단 AI 챗',
                              style: IsleText.subtitle(color: Colors.white)
                                  .copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(
                            '"매일 9시까지 Safari 막아줘" — 바로 만들어줘요',
                            style: IsleText.caption(
                                color: Colors.white.withValues(alpha: 0.82)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        color: Colors.white.withValues(alpha: 0.7), size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const _MorningBlockCard(),
            const SizedBox(height: 12),
            const IsleHomeQuickStrip(),
            const SizedBox(height: 12),
            BlockScheduleOverview(
              refreshToken: _refreshToken,
              onRefresh: _load,
              afterHero: [
                const BlockingCapabilitiesBanner(compact: true),
                AlwaysOnAppBlockSection(onChanged: _load),
                if (Platform.isAndroid)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: AndroidBlockingSetupChecklist(onChanged: _load),
                    ),
                  ),
                const SafariYoutubeInboundSection(),
                const WebsiteBlockSection(),
              ],
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 12),
            const _FocusShortcutsCard(),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('도움말 · 빠른 설정',
                  style: IsleText.caption(color: IsleColors.muted)),
              children: [
                if (status != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bolt_outlined,
                        color: IsleColors.muted),
                    title: const Text('Instagram·SNS 3분 설정'),
                    onTap: _setupBusy ? null : _runQuickSetup,
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.public_off, color: IsleColors.muted),
                  title: const Text('Safari 유튜브 → Isle 설정'),
                  onTap: () =>
                      context.push('/settings/browser-youtube-tracking'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Platform.isAndroid ? Icons.android : Icons.phone_iphone,
                    color: IsleColors.muted,
                  ),
                  title: Text(PlatformBlockCopy.blockingCapabilitiesTitle),
                  onTap: () => context.push('/settings/iphone-blocking'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const _SectionTitle('오늘 사용 시간 (Isle 안)'),
            const SizedBox(height: 4),
            Text(
              PlatformBlockCopy.isleInAppUsageFootnote,
              style: IsleText.caption(color: IsleColors.muted)
                  .copyWith(height: 1.35),
            ),
            const SizedBox(height: 8),
            _TodayUsageCard(today: _today, loading: _loading),
            const SizedBox(height: 10),
            _Weekly7dayCard(daily: _daily, loading: _loading),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.push('/settings/platform-stats'),
              icon: const Icon(Icons.bar_chart_outlined),
              label: const Text('자세한 통계 보기'),
            ),

            if (_suggestion != null) ...[
              const SizedBox(height: 12),
              _SuggestionBanner(
                suggestion: _suggestion!,
                onAction: () => _handleSuggestion(_suggestion!),
                onDismiss: () => setState(() => _suggestion = null),
              ),
            ],

            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('고급 · YouTube·한도',
                  style: IsleText.subtitle(color: IsleColors.ocean900)),
              initiallyExpanded: false,
              subtitle: Text(
                'Safari 차단, 일일 N분 한도 등',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading:
                      const Icon(Icons.public_off, color: IsleColors.muted),
                  title: const Text('Isle 밖 YouTube (Safari)'),
                  subtitle: Text(PlatformBlockCopy.externalBrowserName),
                  trailing: const Icon(Icons.chevron_right,
                      color: IsleColors.muted, size: 20),
                  onTap: () => context.push(PlatformBlockCopy.settingsRoute),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading:
                      const Icon(Icons.timer_outlined, color: IsleColors.muted),
                  title: const Text('앱별 일일 시간 한도'),
                  trailing: const Icon(Icons.chevron_right,
                      color: IsleColors.muted, size: 20),
                  onTap: () => context.push('/settings/app-usage-limits'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.tune, color: IsleColors.muted),
                  title: const Text('YouTube 잠금 단계'),
                  trailing: const Icon(Icons.chevron_right,
                      color: IsleColors.muted, size: 20),
                  onTap: () => context.push(IsleRoutes.youtubeLimits),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runQuickSetup() async {
    if (!IsleApplePlatform.isNativeBlockHost) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 기기에서는 네이티브 앱 차단을 지원하지 않아요')),
      );
      return;
    }
    setState(() => _setupBusy = true);
    try {
      final result = await BlockFocusService.runInstagramBlockSetup();
      if (!mounted) return;
      if (result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '설정 완료')),
        );
        final sid = result.scheduleId;
        if (sid != null && sid.isNotEmpty) {
          pushBlockScheduleEdit(context, sid);
        }
      } else if (!result.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? '설정 실패'),
            action: result.denied
                ? SnackBarAction(
                    label: '설정',
                    onPressed: () =>
                        IosScreenTimeService.openScreenTimeSettings(),
                  )
                : result.deniedAndroid
                    ? SnackBarAction(
                        label: '접근성',
                        onPressed: () async {
                          await resolveBlockingController()
                              .openSystemSettings();
                        },
                      )
                    : null,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _setupBusy = false);
        await _load();
      }
    }
  }

  Future<void> _handleSuggestion(BlockSuggestion s) async {
    switch (s.actionKind) {
      case 'add_night_schedule':
        await BlockFocusService.ensureNightSnsSchedule();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SNS 야간 차단 (21:00–07:00) 스케줄을 켰어요')),
        );
        break;
      case 'pick_apps':
        await _runQuickSetup();
        return;
      case 'lower_limit':
        await context.push('/settings/app-usage-limits');
        break;
    }
    if (mounted) await _load();
  }
}

// ───────────────────────────────────────────────────────── Widgets ──

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: IsleText.subtitle(color: IsleColors.ocean900));
}

class _SuggestionBanner extends StatelessWidget {
  const _SuggestionBanner({
    required this.suggestion,
    required this.onAction,
    required this.onDismiss,
  });
  final BlockSuggestion suggestion;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IsleColors.gold500.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IsleColors.gold500.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: IsleColors.gold500, size: 18),
              const SizedBox(width: 8),
              Text('제안',
                  style: IsleText.caption(color: IsleColors.ocean900)
                      .copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon:
                    const Icon(Icons.close, size: 18, color: IsleColors.muted),
                onPressed: onDismiss,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(suggestion.title,
              style: IsleText.subtitle(color: IsleColors.ocean900)),
          const SizedBox(height: 4),
          Text(suggestion.body,
              style: IsleText.caption(color: IsleColors.ocean700)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.arrow_forward),
            label: Text(suggestion.actionLabel),
            style: FilledButton.styleFrom(
              backgroundColor: IsleColors.gold500,
              foregroundColor: IsleColors.ocean900,
              minimumSize: const Size.fromHeight(IsleSize.minTouchTarget),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayUsageCard extends StatelessWidget {
  const _TodayUsageCard({required this.today, required this.loading});
  final Map<String, int> today;
  final bool loading;

  static const _icons = {
    'youtube': Icons.ondemand_video,
    'instagram': Icons.camera_alt_outlined,
    'brunch': Icons.article_outlined,
  };
  static const _colors = {
    'youtube': Color(0xFFFF0000),
    'instagram': Color(0xFFE1306C),
    'brunch': Color(0xFF00C6BE),
  };

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _shell(const Center(
          child: SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      )));
    }
    final total = today.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return _shell(Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '오늘 기록 없음 — Isle 안에서 영상을 보면 자동 집계돼요',
          textAlign: TextAlign.center,
          style: IsleText.caption(color: IsleColors.muted),
        ),
      ));
    }
    final maxSec = today.values.fold<int>(0, (a, b) => a > b ? a : b);

    return _shell(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in PlatformUsageStats.platforms) ...[
          if (PlatformUsageStats.platforms.indexOf(p) > 0)
            const SizedBox(height: 10),
          _row(p, today[p] ?? 0, maxSec),
        ],
      ],
    ));
  }

  Widget _row(String p, int sec, int maxSec) {
    final ratio = maxSec > 0 ? sec / maxSec : 0.0;
    return Row(
      children: [
        Icon(_icons[p] ?? Icons.timer, size: 18, color: _colors[p]),
        const SizedBox(width: 8),
        SizedBox(
          width: 76,
          child: Text(PlatformUsageStats.labelFor(p), style: IsleText.body()),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: sec == 0 ? 0 : ratio.clamp(0.05, 1.0),
              minHeight: 8,
              backgroundColor: IsleColors.ocean100,
              color: _colors[p] ?? IsleColors.ocean500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(
            PlatformUsageStats.formatDuration(sec),
            textAlign: TextAlign.right,
            style: IsleText.caption(color: IsleColors.ocean700),
          ),
        ),
      ],
    );
  }

  Widget _shell(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: child,
    );
  }
}

class _Weekly7dayCard extends StatelessWidget {
  const _Weekly7dayCard({required this.daily, required this.loading});
  final Map<String, Map<String, int>> daily;
  final bool loading;

  static const _colors = {
    'youtube': Color(0xFFFF0000),
    'instagram': Color(0xFFE1306C),
    'brunch': Color(0xFF00C6BE),
  };

  @override
  Widget build(BuildContext context) {
    if (loading || daily.isEmpty) return const SizedBox.shrink();

    final maxDay = daily.values
        .map((m) => m.values.fold<int>(0, (a, b) => a + b))
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (maxDay == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('최근 7일',
                  style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Wrap(
                spacing: 8,
                children: PlatformUsageStats.platforms
                    .map(
                      (p) => Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _colors[p],
                              shape: BoxShape.circle,
                            )),
                        const SizedBox(width: 4),
                        Text(PlatformUsageStats.labelFor(p),
                            style: IsleText.caption(color: IsleColors.muted)),
                      ]),
                    )
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: daily.entries.map((e) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _stackedBar(e.value, maxDay, e.key),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stackedBar(Map<String, int> day, int maxSec, String dayKey) {
    final total = day.values.fold<int>(0, (a, b) => a + b);
    final h = maxSec > 0 ? (90 * (total / maxSec)).clamp(0.0, 90.0) : 0.0;
    final dayLabel = dayKey.split('-').last;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
              child: SizedBox(
                width: double.infinity,
                height: h,
                child: Column(
                  children: PlatformUsageStats.platforms.map((p) {
                    final s = day[p] ?? 0;
                    if (s == 0 || total == 0) return const SizedBox.shrink();
                    return Expanded(
                      flex: s,
                      child: Container(color: _colors[p]),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(dayLabel,
            style: IsleText.caption(color: IsleColors.muted)
                .copyWith(fontSize: 10)),
      ],
    );
  }
}

/// 아침 차단 빠른 설정 카드 — 카카오·릴스·숏츠·Safari 한 번에
class _MorningBlockCard extends StatelessWidget {
  const _MorningBlockCard();

  static const _scenarios = [
    _MorningScenario(
      icon: Icons.wb_sunny_outlined,
      label: '아침 Safari 차단',
      color: Color(0xFFE65100),
      prompt: '매일 9시까지 Safari 차단해줘',
    ),
    _MorningScenario(
      icon: Icons.chat_bubble_outline,
      label: '카카오 + 인스타 차단',
      color: Color(0xFF6B2FBB),
      prompt: '매일 아침 9시까지 인스타·SNS 차단 스케줄 만들어줘',
    ),
    _MorningScenario(
      icon: Icons.play_circle_outline,
      label: '릴스 + 숏츠 숨기기',
      color: Color(0xFFE1306C),
      prompt: '인스타 릴스 숨기고 유튜브 숏츠도 숨겨줘',
    ),
    _MorningScenario(
      icon: Icons.timer_outlined,
      label: '유튜브 아침 차단',
      color: Color(0xFFFF0000),
      prompt: '매일 9시까지 유튜브 차단해줘',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny, color: Color(0xFFFF8F00), size: 20),
                const SizedBox(width: 8),
                Text('아침 차단 빠른 설정',
                    style: IsleText.subtitle(color: IsleColors.ocean900)
                        .copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('챗으로 즉시 적용',
                    style: IsleText.caption(color: IsleColors.muted)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              children: [
                const SizedBox(height: 4),
                Text(
                  PlatformBlockCopy.morningBlockQuickNote,
                  style: IsleText.caption(color: IsleColors.muted)
                      .copyWith(height: 1.4),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 2.8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: _scenarios
                      .map((s) => _ScenarioChip(scenario: s))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MorningScenario {
  const _MorningScenario({
    required this.icon,
    required this.label,
    required this.color,
    required this.prompt,
  });
  final IconData icon;
  final String label;
  final Color color;
  final String prompt;
}

class _ScenarioChip extends StatelessWidget {
  const _ScenarioChip({required this.scenario});
  final _MorningScenario scenario;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scenario.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push(
          '/settings/block-chat?q=${Uri.encodeComponent(scenario.prompt)}',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(scenario.icon, color: scenario.color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  scenario.label,
                  style: IsleText.caption(color: IsleColors.ocean900)
                      .copyWith(fontWeight: FontWeight.w600, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 집중 UI — 유튜브·지식·분야 차단 바로가기
class _FocusShortcutsCard extends StatelessWidget {
  const _FocusShortcutsCard();

  @override
  Widget build(BuildContext context) {
    if (!IsleProductFocus.enabled) return const SizedBox.shrink();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('유튜브·필터',
                style: IsleText.subtitle(color: IsleColors.ocean900)),
          ),
          ListTile(
            leading: const Icon(Icons.tune, color: Color(0xFFFF0000)),
            title: const Text('유튜브·SNS 관리'),
            subtitle: const Text('숏츠 숨기기 · 채널/키워드 차단 · 한도'),
            onTap: () => context.push('/home/my-isle/manage'),
          ),
          ListTile(
            leading: const Icon(Icons.play_circle, color: Color(0xFFFF0000)),
            title: const Text('나의 Isle · YouTube'),
            subtitle: const Text('링크 붙여넣기 · Isle 유튜브에서 보기'),
            onTap: () => context.go('/home/my-isle'),
          ),
          ListTile(
            leading:
                const Icon(Icons.category_outlined, color: IsleColors.ocean700),
            title: const Text('분야·키워드 차단 (AI)'),
            subtitle: const Text('예: 스타크래프트2 — 비슷한 채널 일괄'),
            onTap: () => context.push('/settings/channel-genre'),
          ),
          ListTile(
            leading:
                const Icon(Icons.badge_outlined, color: IsleColors.ocean900),
            title: const Text('지식 명함'),
            onTap: () => context.push('/knowledge/profile'),
          ),
        ],
      ),
    );
  }
}
