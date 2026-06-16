import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_release_info.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/navigation/isle_routes.dart';
import '../../../core/qa/device_qa_preflight_service.dart';
import '../../../core/qa/device_qa_store.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../../shared/widgets/isle_developer_delay_report_card.dart';
import '../../youtube/presentation/widgets/isle_youtube_schedule_sheet.dart';

class DeviceQaItemDef {
  const DeviceQaItemDef({
    required this.id,
    required this.title,
    required this.steps,
    this.route,
    this.sheetAction,
  });

  final String id;
  final String title;
  final String steps;
  final String? route;
  final String? sheetAction;
}

/// TODO §1 실기기 확인 — 체크·딥링크
class DeviceQaScreen extends StatefulWidget {
  const DeviceQaScreen({super.key});

  static const qaItemIds = [
    'youtube_voice',
    'ai_schedule',
    'ai_isle_yt_schedule',
    'youtube_limits_ui',
    'pomodoro',
    'kakao_refill',
    'youtube_account',
    'android_blocking',
    'build_smoke',
    'deploy_macos',
    'deploy_ios',
    'deploy_vercel',
  ];

  @override
  State<DeviceQaScreen> createState() => _DeviceQaScreenState();
}

class _DeviceQaScreenState extends State<DeviceQaScreen> {
  Set<String> _checked = {};
  Map<String, DeviceQaPreflightResult> _preflight = {};
  bool _preflightLoading = true;

  static List<DeviceQaItemDef> get _items => [
    DeviceQaItemDef(
      id: 'youtube_voice',
      title: '유튜브 음성',
      steps: '① Google 로그인 ② 구독 탭 ③ 내 영상 ④ 내 채널 영상 재생·소리',
      route: '/youtube/podcast',
    ),
    DeviceQaItemDef(
      id: 'ai_schedule',
      title: 'AI·스케줄',
      steps: '① AI 센터 → 키 붙여넣고 연결 ② Isle 유튜브 스케줄 ③ 차단 AI 챗',
      route: '/settings/ai-hub',
    ),
    DeviceQaItemDef(
      id: 'ai_isle_yt_schedule',
      title: 'Isle 유튜브 스케줄 (수동)',
      steps: '매일 0시~선택 시각까지 앱 안 유튜브 차단 적용',
      sheetAction: 'isle_youtube_schedule',
    ),
    DeviceQaItemDef(
      id: 'youtube_limits_ui',
      title: '유튜브 한도 UI',
      steps: '슬라이더 변경 → 하단 sticky 저장 · 버전 배지와 겹치지 않는지',
      route: IsleRoutes.youtubeLimits,
    ),
    DeviceQaItemDef(
      id: 'pomodoro',
      title: '포모도로',
      steps: '30분 채우면 10분 휴식 · 「지금 보는 중」세션 · OS 카카오 차단',
      route: '/home/block/pomodoro',
    ),
    DeviceQaItemDef(
      id: 'kakao_refill',
      title: '카카오 5분 리필',
      steps: '마스터 ON · OS 한도 · 피커 자동 · iOS=매시간 5분',
      route: '/home/block/pomodoro?tab=refill',
    ),
    DeviceQaItemDef(
      id: 'youtube_account',
      title: 'YouTube 계정 동기화',
      steps: '로그인 · 나중에 볼 · 플레이리스트 동기화',
      route: '/settings/youtube-account-sync',
    ),
    DeviceQaItemDef(
      id: 'android_blocking',
      title: 'Android 차단',
      steps: '① 접근성 Isle 차단 ② 배터리 예외 ③ VPN 웹차단 ④ Chrome 즉시차단',
      route: '/settings/android-system-block',
    ),
    DeviceQaItemDef(
      id: 'build_smoke',
      title: 'Firebase / iPhone / Android APK',
      steps: 'flutter run --flavor full · Desktop APK 설치 · Analytics 이벤트',
      route: '/settings/deploy-guide',
    ),
    DeviceQaItemDef(
      id: 'deploy_macos',
      title: 'macOS DMG 배포',
      steps: 'Xcode macOS Runner 서명(Family Controls) → deploy/scripts/release_mac.sh',
      route: '/settings/deploy-guide',
    ),
    DeviceQaItemDef(
      id: 'deploy_ios',
      title: 'iOS TestFlight',
      steps: 'deploy/scripts/build_ipa_testflight.sh → Organizer → TestFlight',
      route: '/settings/deploy-guide',
    ),
    DeviceQaItemDef(
      id: 'deploy_vercel',
      title: 'Vercel 랜딩 배포',
      steps: 'deploy/web_deploy → GitHub push → Vercel 연결 · downloads URL 갱신',
      route: '/settings/deploy-guide',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _reload();
    unawaited(_runPreflight());
  }

  Future<void> _runPreflight() async {
    setState(() => _preflightLoading = true);
    final r = await DeviceQaPreflightService.runAll();
    if (!mounted) return;
    setState(() {
      _preflight = r;
      _preflightLoading = false;
    });
  }

  void _reload() {
    setState(() => _checked = DeviceQaStore.loadChecked());
  }

  Future<void> _toggle(String id, bool? v) async {
    if (v == null) return;
    await DeviceQaStore.setChecked(id, v);
    _reload();
  }

  Future<void> _open(DeviceQaItemDef item) async {
    if (item.sheetAction == 'isle_youtube_schedule') {
      await showIsleYoutubeScheduleSheet(context);
      return;
    }
    final route = item.route;
    if (route != null && route.isNotEmpty) {
      await context.push(route);
    }
  }

  Future<void> _resetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('체크 초기화'),
        content: const Text('모든 실기기 확인 체크를 지울까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('초기화')),
        ],
      ),
    );
    if (ok == true) {
      await DeviceQaStore.clearAll();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = DeviceQaStore.countChecked(_items.map((e) => e.id));
    final total = _items.length;

    return Scaffold(
      appBar: const IsleAppBar(title: '실기기 확인'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, IsleSize.scrollBottomPadding(context)),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IsleColors.ocean100,
              borderRadius: BorderRadius.circular(IsleSize.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TODO §1 진행', style: IsleText.subtitle(color: IsleColors.ocean900)),
                const SizedBox(height: 6),
                Text(
                  '$done / $total 완료 · ${AppReleaseInfo.label}',
                  style: IsleText.caption(color: IsleColors.ocean700),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  backgroundColor: Colors.white,
                  color: IsleColors.ocean500,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 0),
            child: IsleDeveloperDelayReportCard(compact: true),
          ),
          const SizedBox(height: 12),
          if (_preflightLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '자동 점검 ${_preflight.values.where((e) => e.passed).length}/${_preflight.length}',
                      style: IsleText.caption(color: IsleColors.ocean700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _runPreflight,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('다시 점검'),
                  ),
                ],
              ),
            ),
          ..._items.map((item) {
            final checked = _checked.contains(item.id);
            final pre = _preflight[item.id];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: checked,
                    onChanged: (v) => _toggle(item.id, v),
                    title: Text(item.title, style: IsleText.body()),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pre != null && !_preflightLoading) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                pre.passed ? Icons.check_circle : Icons.warning_amber,
                                size: 16,
                                color: pre.passed ? IsleColors.grassDeep : Colors.orange.shade800,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  pre.summary,
                                  style: IsleText.caption(
                                    color: pre.passed ? IsleColors.ocean700 : Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (pre.hint != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 22, top: 2),
                              child: Text(
                                pre.hint!,
                                style: IsleText.caption(color: IsleColors.muted),
                              ),
                            ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          item.steps,
                          style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
                        ),
                      ],
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (item.route != null || item.sheetAction != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: IsleSize.minTouchTarget,
                        child: OutlinedButton.icon(
                          onPressed: () => _open(item),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('화면 열기'),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
          TextButton(onPressed: _resetAll, child: const Text('체크 전부 초기화')),
        ],
      ),
    );
  }
}
