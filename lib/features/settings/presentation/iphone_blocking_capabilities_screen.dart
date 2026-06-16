import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/blocking/blocking_controller_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/platform/ios_extension_status.dart';
import '../../../core/platform/ios_internal_schedule_lock_controller.dart';
import '../../../core/platform/ios_screen_time_service.dart';
import '../../../core/platform/isle_apple_platform.dart';
import '../../../shared/widgets/blocking_capabilities_banner.dart';
import '../../../shared/widgets/isle_app_bar.dart';

enum _CapStatus { available, partial, planned, unavailable }

/// 6VPN Blocker iPhone 블루프린트 대비 Isle 구현 상태 (투명성 UI).
class IphoneBlockingCapabilitiesScreen extends ConsumerStatefulWidget {
  const IphoneBlockingCapabilitiesScreen({super.key});

  @override
  ConsumerState<IphoneBlockingCapabilitiesScreen> createState() =>
      _IphoneBlockingCapabilitiesScreenState();
}

class _IphoneBlockingCapabilitiesScreenState extends ConsumerState<IphoneBlockingCapabilitiesScreen> {
  bool? _entitlement;
  String _auth = '…';
  IosExtensionStatusResult? _extensions;

  @override
  void initState() {
    super.initState();
    _loadNative();
  }

  Future<void> _loadNative() async {
    if (!Platform.isIOS) return;
    final ent = await IosScreenTimeService.hasFamilyControlsEntitlement();
    final status = await IosScreenTimeService.authorizationStatus();
    final ext = await IosExtensionStatus.load();
    if (!mounted) return;
    setState(() {
      _entitlement = ent;
      _auth = status.name;
      _extensions = ext;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lockMode = IosInternalScheduleLockController.mode;

    return Scaffold(
      appBar: IsleAppBar(
        title: Platform.isAndroid ? 'Android 차단 기능' : 'iPhone 차단 기능',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (Platform.isAndroid) ...[
            Text(
              resolveBlockingController().capabilities.note ?? '',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            const SizedBox(height: 12),
            const BlockingCapabilitiesBanner(),
            const SizedBox(height: 20),
          ] else ...[
          Text(
            'Isle은 VPN 터널이 아니라 Screen Time + 인앱 필터로 동작해요. '
            '아래 표는 6VPN Blocker iPhone 스펙 대비 현재 상태입니다.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          if (Platform.isIOS) ...[
            const SizedBox(height: 12),
            _diagCard(),
          ],
          const SizedBox(height: 20),
          const SizedBox(height: 20),
          ],
          if (Platform.isAndroid) ...[
            Text('L1 — Android OS 연동', style: IsleText.subtitle()),
            _row('접근성 앱 차단', _CapStatus.available, 'Chrome·Instagram 등 즉시 차단'),
            _row('로컬 VPN 웹 차단', _CapStatus.partial, '전 브라우저 DNS · DoH 우회 가능'),
            _row('스케줄별 앱·웹', _CapStatus.available, '스케줄 ON 시 자동 on/off'),
            _row('배터리 최적화 예외', _CapStatus.partial, '삼성·샤오미 — 수동 설정 필요'),
            _row('앱 삭제·잠금', _CapStatus.unavailable, 'Device Owner 없이 OS 잠금 불가'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/settings/android-system-block'),
              icon: const Icon(Icons.android),
              label: const Text('Android 시스템 차단 설정'),
            ),
            const SizedBox(height: 16),
          ] else ...[
          Text('L1 — OS Screen Time (앱·웹)', style: IsleText.subtitle()),
          _row(
            'Family Controls 권한',
            _CapStatus.available,
            '차단 탭 · Screen Time 허용',
          ),
          _row(
            '스케줄 시간에 도메인·앱 쉴드',
            _CapStatus.available,
            '스케줄 ON + 앱 선택 시 OS 차단',
          ),
          _row(
            '스케줄별 앱 선택 blob',
            _CapStatus.available,
            '스케줄 편집 → 이 스케줄의 앱 차단 · 활성 시 union',
          ),
          _row(
            'BGTask / DeviceActivity 스케줄 경계',
            _extensions?.deviceActivityMonitor == true ? _CapStatus.available : _CapStatus.partial,
            _extensions?.deviceActivityMonitor == true
                ? 'Monitor 확장 · BGTask scheduleSync'
                : 'ios/embed_isle_extensions.rb 후 재빌드',
          ),
          const SizedBox(height: 16),
          Text('L2 — Safari / 검색 숨김', style: IsleText.subtitle()),
          _row(
            'Safari Content Blocker',
            _extensions?.safariContentBlocker == true ? _CapStatus.available : _CapStatus.partial,
            _extensions?.safariContentBlocker == true
                ? '임베드됨 · Safari 설정에서 확장 ON'
                : 'ruby ios/embed_isle_extensions.rb 후 재빌드',
          ),
          _row(
            'YouTube 검색·피드 키워드 숨김',
            _CapStatus.available,
            '인앱 WebView + Isle 피드',
          ),
          _row(
            'Google 검색 결과 숨김',
            _CapStatus.available,
            '인앱 웹(custom) + 키워드 필터',
          ),
          _row(
            'YouTube/Safari 공식 앱 검색',
            _CapStatus.unavailable,
            'Apple 정책 — OS 밖 UI 수정 불가',
          ),
          const SizedBox(height: 16),
          Text('L3 — 인앱 잠금 오버레이', style: IsleText.subtitle()),
          _row('스케줄 중 Isle UI 차단', _CapStatus.available, '아래 모드에서 동작'),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: SegmentedButton<IosInternalLockMode>(
              segments: const [
                ButtonSegment(value: IosInternalLockMode.off, label: Text('끔')),
                ButtonSegment(value: IosInternalLockMode.auto, label: Text('자동')),
                ButtonSegment(value: IosInternalLockMode.always, label: Text('항상')),
              ],
              selected: {lockMode},
              onSelectionChanged: (s) async {
                await IosInternalScheduleLockController.setMode(s.first);
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(height: 16),
          ],
          Text('콘텐츠 필터 (Isle 고유)', style: IsleText.subtitle()),
          _row('채널 전체 숨김', _CapStatus.available, '차단한 채널 · 일괄 붙여넣기'),
          _row('영상 1개 숨김', _CapStatus.available, '링크로 숨기기'),
          _row('키워드 숨김', _CapStatus.available, '설정 → 숨길 키워드'),
          _row('데이터 백업·복구', _CapStatus.available, '설정 → 데이터 백업'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/home/block'),
            icon: const Icon(Icons.shield),
            label: const Text('차단 허브 열기'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/settings/blocked-channels'),
            icon: const Icon(Icons.playlist_add),
            label: const Text('유튜브 목록 일괄 차단'),
          ),
        ],
      ),
    );
  }

  Widget _diagCard() {
    final ent = _entitlement;
    final ext = _extensions;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이 기기 진단', style: IsleText.body().copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Family Controls entitlement: ${ent == true ? '있음' : ent == false ? '없음(재서명 필요)' : '확인 중'}',
                style: IsleText.caption()),
            Text('Screen Time 권한: $_auth', style: IsleText.caption()),
            Text(
              'iOS 지원: ${IsleApplePlatform.isScreenTimeHost ? '예' : '아니오'}',
              style: IsleText.caption(),
            ),
            if (ext != null) ...[
              const SizedBox(height: 6),
              Text(
                'Device Activity 확장: ${ext.deviceActivityMonitor ? '임베드됨' : '없음 — ios/embed_isle_extensions.rb'}',
                style: IsleText.caption(
                  color: ext.deviceActivityMonitor ? IsleColors.grassDeep : IsleColors.gold500,
                ),
              ),
              Text(
                'Safari Content Blocker: ${ext.safariContentBlocker ? '임베드됨' : '없음'}',
                style: IsleText.caption(
                  color: ext.safariContentBlocker ? IsleColors.grassDeep : IsleColors.gold500,
                ),
              ),
            ],
            if (ext != null && !ext.safariContentBlocker) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => IosExtensionStatus.openSafariSettings(),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Safari 설정 열기'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String title, _CapStatus status, String detail) {
    return ListTile(
      leading: Icon(_icon(status), color: _color(status)),
      title: Text(title, style: IsleText.body()),
      subtitle: Text('${_label(status)} · $detail', style: IsleText.caption(color: IsleColors.muted)),
    );
  }

  static IconData _icon(_CapStatus s) => switch (s) {
        _CapStatus.available => Icons.check_circle,
        _CapStatus.partial => Icons.construction,
        _CapStatus.planned => Icons.schedule,
        _CapStatus.unavailable => Icons.block,
      };

  static Color _color(_CapStatus s) => switch (s) {
        _CapStatus.available => IsleColors.grassDeep,
        _CapStatus.partial => IsleColors.gold500,
        _CapStatus.planned => IsleColors.ocean500,
        _CapStatus.unavailable => IsleColors.muted,
      };

  static String _label(_CapStatus s) => switch (s) {
        _CapStatus.available => '사용 가능',
        _CapStatus.partial => '부분',
        _CapStatus.planned => '준비 중',
        _CapStatus.unavailable => '불가',
      };
}
