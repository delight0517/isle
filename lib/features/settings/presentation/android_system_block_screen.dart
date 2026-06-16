import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/blocking/blocking_controller_provider.dart';
import '../../../shared/widgets/android_blocking_setup_checklist.dart';
import '../../../shared/widgets/blocking_capabilities_banner.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/intervention/app_intervention_service.dart';
import '../../../core/intervention/external_app_shield_store.dart';
import '../../../core/intervention/website_block_store.dart';
import '../../../core/safety/content_safety_guard.dart';
import '../../../core/platform/platform_block_intent.dart';

/// Android — Safari/Screen Time 대체: Isle 접근성 앱 차단 + Wellbeing · DNS · Chrome
class AndroidSystemBlockScreen extends StatefulWidget {
  const AndroidSystemBlockScreen({super.key});

  @override
  State<AndroidSystemBlockScreen> createState() => _AndroidSystemBlockScreenState();
}

class _AndroidSystemBlockScreenState extends State<AndroidSystemBlockScreen> {
  bool _accessibilityOn = false;
  int _blockedCount = 0;
  int _webDomainCount = 0;
  bool _webBlockOn = false;
  bool _loading = true;
  bool _busy = false;
  bool _webBusy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await ExternalAppShieldStore.ensureOpen();
    await WebsiteBlockStore.ensureOpen();
    final on = await resolveBlockingController().isAuthorized();
    if (!mounted) return;
    setState(() {
      _accessibilityOn = on;
      _blockedCount = ExternalAppShieldStore.applicationCount;
      _webDomainCount = WebsiteBlockStore.loadDomains().length;
      _loading = false;
    });
  }

  Future<void> _toggleWebBlock(bool enable) async {
    if (_webBusy) return;
    setState(() => _webBusy = true);
    try {
      final c = resolveBlockingController();
      if (!enable) {
        await c.clearWebBlock();
        if (mounted) setState(() => _webBlockOn = false);
        return;
      }
      final domains = {
        ...WebsiteBlockStore.loadDomains(),
        ...ContentSafetyGuard.exportBlockDomains(),
      }.toList();
      if (domains.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('차단할 웹사이트를 차단 허브에서 먼저 추가하세요')),
          );
        }
        return;
      }
      final ok = await c.applyWebBlock(domains);
      if (mounted) {
        setState(() => _webBlockOn = ok);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? '웹사이트 차단을 켰어요 (${domains.length}개 도메인)' : 'VPN 권한이 필요해요'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _webBusy = false);
    }
  }

  Future<void> _pickAndBlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await AppInterventionService.pickApps();
      if (res == null) {
        await _refresh();
        if (mounted && !_accessibilityOn) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('설정 → 접근성 → Isle 차단 서비스를 켠 뒤 다시 시도해 주세요'),
            ),
          );
        }
        return;
      }
      if (res.encoded.isEmpty) {
        await AppInterventionService.clearAppShield();
        await ExternalAppShieldStore.clearSelection();
      } else {
        await ExternalAppShieldStore.savePickResult(
          encoded: res.encoded,
          applicationCount: res.applicationCount,
          categoryCount: res.categoryCount,
        );
        await AppInterventionService.applySavedAppShield();
      }
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.encoded.isEmpty ? '차단 해제됨' : '${res.applicationCount}개 앱을 차단했어요',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearBlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AppInterventionService.clearAppShield();
      await ExternalAppShieldStore.clearSelection();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('차단 해제됨')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openWellbeing(BuildContext context) async {
    try {
      final settings = Uri.parse('app-settings:');
      if (await launchUrl(settings, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('설정 → 디지털 웰빙 → 앱 타이머에서 YouTube·Chrome을 제한하세요'),
        ),
      );
    }
  }

  Future<void> _copyDnsHosts(BuildContext context) async {
    const block = '''
# Isle — Private DNS 또는 필터 DNS용 참고 도메인
youtube.com
m.youtube.com
www.youtube.com
youtu.be
''';
    await Clipboard.setData(const ClipboardData(text: block));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('도메인 목록 복사됨')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(PlatformBlockCopy.settingsTileTitle, style: IsleText.subtitle()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const BlockingCapabilitiesBanner(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AndroidBlockingSetupChecklist(onChanged: _refresh),
            ),
          ),
          const SizedBox(height: 12),
          _appBlockSection(context),
          const SizedBox(height: 20),
          Card(
            color: IsleColors.ocean100,
            child: ListTile(
              leading: const Icon(Icons.track_changes, color: IsleColors.ocean700),
              title: Text('브라우저 유튜브 → Isle 트래킹', style: IsleText.subtitle()),
              subtitle: Text(
                'Chrome 차단 후 Isle WebView에서 시청·시간 기록',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/browser-youtube-tracking'),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1538),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Android 네이티브 경로', style: IsleText.subtitle(color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  'Chrome·YouTube 앱에서 유튜브를 줄이고, '
                  '시청·통계는 Isle WebView에서만 잡힙니다.',
                  style: IsleText.caption(color: Colors.white70).copyWith(height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _section('① 앱·브라우저별 (권장)'),
          _tile(
            icon: Icons.hourglass_bottom,
            title: '디지털 웰빙 · 앱 타이머',
            body: 'YouTube · Chrome에 일일 시간 제한 또는 일시 정지',
            action: '설정 열기',
            onTap: () => _openWellbeing(context),
          ),
          _tile(
            icon: Icons.language,
            title: 'Chrome — 사이트 설정',
            body: 'Chrome 설정 → 사이트 설정 → youtube.com 제한 (Chrome만)',
            action: '안내',
            onTap: () async {
              final u = Uri.parse('https://support.google.com/chrome/answer/95647');
              await launchUrl(u, mode: LaunchMode.externalApplication);
            },
          ),
          const SizedBox(height: 16),
          _section('② 기기 전역 (고급)'),
          _tile(
            icon: Icons.dns,
            title: 'Private DNS (DoH)',
            body: '설정 → 네트워크 → Private DNS — 필터 DNS (전 브라우저)',
            action: '도메인 복사',
            onTap: () => _copyDnsHosts(context),
          ),
          _webBlockTile(),
          const SizedBox(height: 16),
          _section('③ Isle 앱 안'),
          Text(
            'WebView 유튜브 · 일일 한도 · 차단 스케줄 · 채널 필터는 Android에서도 동일합니다.',
            style: IsleText.body(color: IsleColors.muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/settings/youtube-default-open'),
            icon: const Icon(Icons.open_in_new),
            label: const Text('YouTube 링크 → Isle에서 열기 (기본 앱)'),
          ),
        ],
      ),
    );
  }

  /// Phase 1 — Isle 접근성 기반 앱 즉시 차단 (iOS Screen Time 앱 쉴드의 Android 등가).
  Widget _appBlockSection(BuildContext context) {
    final statusColor = _accessibilityOn ? const Color(0xFF2E7D32) : IsleColors.danger;
    final statusText = _loading
        ? '확인 중…'
        : (_accessibilityOn ? '접근성 차단 서비스 켜짐' : '접근성 차단 서비스 꺼짐');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: IsleColors.ocean700),
              const SizedBox(width: 8),
              Expanded(
                child: Text('앱 즉시 차단 (Isle)', style: IsleText.subtitle()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: statusColor),
              const SizedBox(width: 6),
              Text(statusText, style: IsleText.caption(color: statusColor)),
              if (!_loading && _blockedCount > 0) ...[
                const Spacer(),
                Text('$_blockedCount개 차단 중', style: IsleText.caption(color: IsleColors.ocean700)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '선택한 앱이 열리면 Isle가 차단 화면을 띄웁니다. iOS Screen Time과 달리 '
            'OS가 강제하지 않는 접근성 기반이라, 설정에서 접근성을 끄면 우회될 수 있어요.',
            style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _pickAndBlock,
                  icon: const Icon(Icons.apps, size: 18),
                  label: Text(_blockedCount > 0 ? '차단할 앱 수정' : '차단할 앱 선택'),
                ),
              ),
              if (!_loading && _blockedCount > 0) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _clearBlock,
                  child: const Text('해제'),
                ),
              ],
            ],
          ),
          if (!_loading && !_accessibilityOn) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      await resolveBlockingController().openSystemSettings();
                    },
              icon: const Icon(Icons.settings_accessibility, size: 18),
              label: const Text('접근성 설정 열기'),
            ),
          ],
        ],
      ),
    );
  }

  /// Phase 2 — 로컬 VpnService DNS 필터로 전 브라우저 웹사이트 차단 (베타).
  Widget _webBlockTile() {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_lock_outlined, color: IsleColors.ocean700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '웹사이트 차단 (전 브라우저 · 베타)',
                        style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _webDomainCount > 0
                            ? '차단 허브에 등록된 $_webDomainCount개 도메인 · 로컬 VPN DNS 필터'
                            : '차단 허브에서 사이트를 추가한 뒤 켜세요',
                        style: IsleText.caption(color: IsleColors.muted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _webBlockOn,
                  onChanged: _webBusy ? null : (v) => _toggleWebBlock(v),
                ),
              ],
            ),
            Text(
              'DoH(암호화 DNS)를 쓰는 브라우저는 우회될 수 있어요. VPN 권한이 필요합니다.',
              style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: IsleText.subtitle()),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    required String body,
    required String? action,
    required VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: IsleColors.ocean700),
        title: Text(title, style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(body, style: IsleText.caption(color: IsleColors.muted)),
        trailing: action == null ? null : TextButton(onPressed: onTap, child: Text(action)),
        onTap: onTap,
      ),
    );
  }
}
