import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/library/platform_usage_stats.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 인스타·유튜브·브런치 — 앱 내 체류 시간
class PlatformUsageStatsScreen extends StatefulWidget {
  const PlatformUsageStatsScreen({super.key});

  @override
  State<PlatformUsageStatsScreen> createState() =>
      _PlatformUsageStatsScreenState();
}

class _PlatformUsageStatsScreenState extends State<PlatformUsageStatsScreen> {
  Map<String, int> _seconds = {};
  int _macBrowserSec = 0;
  PlatformUsageReport? _report;
  var _loading = true;
  var _reportExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await PlatformUsageStats.secondsByPlatform();
    final macBrowser = await PlatformUsageStats.macBrowserSecondsToday();
    final report = await PlatformUsageStats.buildReport();
    if (!mounted) return;
    setState(() {
      _seconds = s;
      _macBrowserSec = macBrowser;
      _report = report;
      _loading = false;
    });
  }

  Future<void> _copyReportLog() async {
    final report = _report ?? await PlatformUsageStats.buildReport();
    await Clipboard.setData(ClipboardData(text: report.copyLog()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('사용 시간 리포트와 판단 이유 로그를 복사했어요')),
    );
  }

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
    final total = _seconds.values.fold<int>(0, (a, b) => a + b);
    final maxSec = _seconds.values.fold<int>(0, (a, b) => a > b ? a : b);
    final report = _report;

    return Scaffold(
      appBar: IsleAppBar(
        title: '플랫폼 사용 시간',
        actions: [
          IconButton(
            onPressed: _loading ? null : _copyReportLog,
            icon: const Icon(Icons.copy_outlined),
            tooltip: '리포트 복사',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Isle 앱 안에서 보낸 시간이에요. '
                    '탐색·유튜브 WebView·브런치 브라우저 체류가 합산됩니다.',
                    style: IsleText.caption(color: IsleColors.muted),
                  ),
                  const SizedBox(height: 20),
                  if (report != null) ...[
                    _UsageReportSummary(
                      report: report,
                      expanded: _reportExpanded,
                      onToggle: () => setState(
                        () => _reportExpanded = !_reportExpanded,
                      ),
                      onCopy: _copyReportLog,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (total == 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        '아직 기록이 없어요.\n탐색 탭에서 인스타·유튜브·브런치를 열어 보세요.',
                        textAlign: TextAlign.center,
                        style: IsleText.body(color: IsleColors.muted),
                      ),
                    )
                  else if (Platform.isMacOS && _macBrowserSec > 0)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.laptop_mac,
                            color: IsleColors.ocean700),
                        title: Text('Safari·Chrome (Mac)',
                            style: IsleText.subtitle()),
                        subtitle: Text(
                          'Isle 실행 중 브라우저 전면 시간',
                          style: IsleText.caption(color: IsleColors.muted),
                        ),
                        trailing: Text(
                          PlatformUsageStats.formatDuration(_macBrowserSec),
                          style: IsleText.subtitle(color: IsleColors.ocean700),
                        ),
                      ),
                    ),
                  ...PlatformUsageStats.platforms.map((platform) {
                    final sec = _seconds[platform] ?? 0;
                    final ratio = maxSec > 0 ? sec / maxSec : 0.0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _icons[platform] ?? Icons.timer,
                                  color:
                                      _colors[platform] ?? IsleColors.ocean500,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  PlatformUsageStats.labelFor(platform),
                                  style: IsleText.subtitle(),
                                ),
                                const Spacer(),
                                Text(
                                  PlatformUsageStats.formatDuration(sec),
                                  style: IsleText.subtitle(
                                      color: IsleColors.ocean700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: ratio.clamp(0.05, 1.0),
                                minHeight: 8,
                                backgroundColor: IsleColors.ocean100,
                                color: _colors[platform] ?? IsleColors.ocean500,
                              ),
                            ),
                            if (total > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '전체의 ${(100 * sec / total).round()}%',
                                  style:
                                      IsleText.caption(color: IsleColors.muted),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _UsageReportSummary extends StatelessWidget {
  const _UsageReportSummary({
    required this.report,
    required this.expanded,
    required this.onToggle,
    required this.onCopy,
  });

  final PlatformUsageReport report;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final top = report.topPlatform;
    final busiestHour = report.busiestHour;
    final busiestDay = report.busiestDay;

    return Card(
      color: IsleColors.ocean100,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_outlined,
                      color: IsleColors.ocean700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '사용 패턴 리포트',
                      style: IsleText.subtitle(color: IsleColors.ocean900),
                    ),
                  ),
                  IconButton(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_outlined, size: 20),
                    tooltip: '판단 이유 로그 복사',
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ReportMetricChip(
                    label: '최근 ${report.days}일 평균',
                    value: PlatformUsageStats.formatDuration(
                      report.averageSecondsPerDay,
                    ),
                  ),
                  _ReportMetricChip(
                    label: '많이 쓴 서비스',
                    value: top == null
                        ? '데이터 없음'
                        : PlatformUsageStats.labelFor(top.platform),
                  ),
                  _ReportMetricChip(
                    label: '많은 시간대',
                    value: busiestHour?.label ?? '기록 대기',
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 14),
                _ReportLine(
                  icon: Icons.today_outlined,
                  text: busiestDay == null
                      ? '아직 가장 많이 쓴 날을 판단할 만큼 기록이 없어요.'
                      : '가장 많이 쓴 날은 ${busiestDay.day}, ${PlatformUsageStats.formatDuration(busiestDay.seconds)}예요.',
                ),
                _ReportLine(
                  icon: Icons.schedule_outlined,
                  text: busiestHour == null
                      ? '시간대 분석은 이번 버전부터 쌓이는 기록으로 계산해요.'
                      : '${busiestHour.label}에 가장 많이 사용했어요.',
                ),
                _ReportLine(
                  icon: Icons.query_stats_outlined,
                  text: top == null
                      ? '플랫폼별 사용 비중은 아직 계산할 수 없어요.'
                      : '${PlatformUsageStats.labelFor(top.platform)}가 가장 많고 ${PlatformUsageStats.formatDuration(top.seconds)}예요.',
                ),
                const SizedBox(height: 10),
                Text('판단 이유', style: IsleText.body()),
                const SizedBox(height: 6),
                ...report.reasons.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $r',
                      style: IsleText.caption(color: IsleColors.muted),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.content_copy, size: 18),
                    label: const Text('리포트 로그 복사'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportMetricChip extends StatelessWidget {
  const _ReportMetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: IsleText.caption(color: IsleColors.muted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: IsleText.body(color: IsleColors.ocean900)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ReportLine extends StatelessWidget {
  const _ReportLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: IsleColors.ocean700),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: IsleText.caption())),
        ],
      ),
    );
  }
}
