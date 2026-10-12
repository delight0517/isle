import 'package:flutter/material.dart';
import '../../../core/localization/moa_strings.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/schedule_overlay_navigation.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/library/platform_usage_stats.dart';

/// 시간관리 탭 — 인앱 사용 시간 통계 + 한도·스케줄 설정
class TimeManagementScreen extends StatefulWidget {
  const TimeManagementScreen({super.key});

  @override
  State<TimeManagementScreen> createState() => _TimeManagementScreenState();
}

class _TimeManagementScreenState extends State<TimeManagementScreen> {
  Map<String, Map<String, int>> _daily = const {};
  Map<String, int> _today = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final daily = await PlatformUsageStats.dailyByPlatform(days: 7);
    final today = await PlatformUsageStats.todayByPlatform();
    if (!mounted) return;
    setState(() {
      _daily = daily;
      _today = today;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _today.values.fold(0, (a, b) => a + b);
    return Scaffold(
      backgroundColor: IsleColors.purple100,
      appBar: _TimeAppBar(),
      body: RefreshIndicator(
        color: IsleColors.purple700,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            // ── 주간 요약 헤더 ────────────────────────────
            _WeeklySummaryCard(
                daily: _daily, todayTotal: total, loading: _loading),
            const SizedBox(height: 14),

            _ChatShortcutCard(
              onTap: () => context.push('/settings/block-chat'),
            ),
            const SizedBox(height: 14),

            // ── 플랫폼별 오늘 ────────────────────────────
            _SectionLabel(MoaStrings.of(context).t('today')),
            const SizedBox(height: 8),
            _PlatformStatCards(today: _today, loading: _loading),
            const SizedBox(height: 14),

            // ── 한도·스케줄 설정 ─────────────────────────
            _SectionLabel(MoaStrings.of(context).t('limits')),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.timer_rounded,
              color: const Color(0xFFFF0000),
              title: 'YouTube 시간 한도',
              subtitle: '하루 N분 이상 시청 시 알림·차단',
              onTap: () => context.push('/settings/youtube-limits'),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.smartphone_rounded,
              color: IsleColors.purple700,
              title: '앱별 일일 시간 한도',
              subtitle: 'Instagram · Brunch 등 한도',
              onTap: () => context.push('/settings/app-usage-limits'),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.calendar_today_rounded,
              color: const Color(0xFF0EA5E9),
              title: '스케줄 관리',
              subtitle: '요일·시간대별 사용 스케줄',
              onTap: () => pushBlockScheduleList(context),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFFE1306C),
              title: 'Instagram 한도',
              subtitle: '릴스 스크롤 멈춤 · 시간 한도',
              onTap: () => context.push('/settings/instagram-limits'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.push('/settings/platform-stats'),
              icon: const Icon(Icons.bar_chart_rounded,
                  color: IsleColors.purple700),
              label: const Text(
                '자세한 통계 보기',
                style: TextStyle(
                    color: IsleColors.purple700, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: IsleColors.purple100,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.timer_rounded,
                color: IsleColors.purple700, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            MoaStrings.of(context).t('time'),
            style: IsleText.subtitle(color: IsleColors.purple900)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ─────────────────────────── Weekly Summary ─────────────────────────────────

class _WeeklySummaryCard extends StatelessWidget {
  const _WeeklySummaryCard({
    required this.daily,
    required this.todayTotal,
    required this.loading,
  });
  final Map<String, Map<String, int>> daily;
  final int todayTotal;
  final bool loading;

  static const _colors = {
    'youtube': Color(0xFFFF0000),
    'instagram': Color(0xFFE1306C),
    'brunch': Color(0xFF00C6BE),
  };

  @override
  Widget build(BuildContext context) {
    final weekTotal =
        daily.values.expand((m) => m.values).fold(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [IsleColors.purple700, IsleColors.purple500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: IsleColors.purple700.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 주 Isle 사용',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loading ? '...' : PlatformUsageStats.formatDuration(weekTotal),
            style: IsleText.title(color: Colors.white)
                .copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          if (!loading && daily.isNotEmpty) ...[
            const SizedBox(height: 14),
            _MiniBarChart(daily: daily, colors: _colors),
          ],
        ],
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart({required this.daily, required this.colors});
  final Map<String, Map<String, int>> daily;
  final Map<String, Color> colors;

  @override
  Widget build(BuildContext context) {
    final maxDay = daily.values
        .map((m) => m.values.fold(0, (a, b) => a + b))
        .fold(0, (a, b) => a > b ? a : b);
    if (maxDay == 0) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: daily.entries.map((e) {
          final total = e.value.values.fold(0, (a, b) => a + b);
          final h = maxDay > 0 ? (32 * (total / maxDay)).clamp(2.0, 32.0) : 2.0;
          final dayLabel = e.key.split('-').last;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: double.infinity,
                    height: h,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────── Platform Stat Cards ────────────────────────────

class _PlatformStatCards extends StatelessWidget {
  const _PlatformStatCards({required this.today, required this.loading});
  final Map<String, int> today;
  final bool loading;

  static const _meta = {
    'youtube': _PMeta('YouTube', Color(0xFFFF0000), Color(0xFFFFF1F1),
        Icons.play_circle_rounded),
    'instagram': _PMeta('Instagram', Color(0xFFE1306C), Color(0xFFFFF0F5),
        Icons.camera_alt_rounded),
    'brunch': _PMeta(
        'Brunch', Color(0xFF00C389), Color(0xFFF0FDF4), Icons.article_rounded),
  };

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(
            color: IsleColors.purple700, strokeWidth: 2),
      ));
    }
    final maxSec = today.values.fold(0, (a, b) => a > b ? a : b);
    return Column(
      children: PlatformUsageStats.platforms.map((p) {
        final m = _meta[p]!;
        final sec = today[p] ?? 0;
        final ratio = maxSec > 0 ? (sec / maxSec).clamp(0.0, 1.0) : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: m.color.withValues(alpha: 0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: m.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(m.icon, color: m.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(m.label,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1a1a2e))),
                          const Spacer(),
                          Text(
                            sec > 0
                                ? PlatformUsageStats.formatDuration(sec)
                                : '0분',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sec > 0 ? m.color : IsleColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: sec == 0 ? 0 : ratio.clamp(0.04, 1.0),
                          minHeight: 5,
                          backgroundColor: IsleColors.purple100,
                          color: m.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChatShortcutCard extends StatelessWidget {
  const _ChatShortcutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: IsleColors.purple200.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: IsleColors.purple700.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: IsleColors.ocean100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: IsleColors.ocean700,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '말로 시간 관리 설정',
                    style: IsleText.subtitle(color: IsleColors.purple900)
                        .copyWith(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '예: 유튜브 20분만, 밤에는 인스타 막아줘',
                    style: IsleText.caption(color: IsleColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: IsleColors.purple700),
          ],
        ),
      ),
    );
  }
}

class _PMeta {
  const _PMeta(this.label, this.color, this.bgColor, this.icon);
  final String label;
  final Color color;
  final Color bgColor;
  final IconData icon;
}

// ─────────────────────────── Settings Tile ──────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1a1a2e))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: IsleText.caption(color: IsleColors.muted)
                          .copyWith(fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: IsleColors.purple200, size: 22),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: IsleColors.purple700,
        letterSpacing: 0.7,
      ),
    );
  }
}
