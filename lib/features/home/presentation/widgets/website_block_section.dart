import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/blocking/blocking_controller_provider.dart';
import '../../../../core/block_schedule/block_schedule_enforcement_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/intervention/website_block_store.dart';
import 'dart:io' show Platform;

import '../../../../core/platform/ios_extension_status.dart';
import '../../../../core/platform/ios_rules_export_service.dart';
import '../../../../core/block/rule_removal_lock.dart';
import '../../../../shared/widgets/rule_removal_lock_controls.dart';

/// 웹사이트 차단 섹션 — Safari Content Blocker 전용.
/// Chrome 등 다른 브라우저는 iOS 제약상 Isle에서 차단 불가. 이를 명시적으로 안내한다.
class WebsiteBlockSection extends StatefulWidget {
  const WebsiteBlockSection({super.key});

  @override
  State<WebsiteBlockSection> createState() => _WebsiteBlockSectionState();
}

class _WebsiteBlockSectionState extends State<WebsiteBlockSection> {
  List<String> _blocked = const [];
  List<String> _custom = const [];
  bool _saving = false;
  bool _extensionActive = false;
  final _customCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    RuleRemovalLock.finalizeExpiredUnlock();
    unawaited(_load());
  }

  Future<void> _load() async {
    await WebsiteBlockStore.ensureOpen();
    if (Platform.isAndroid) {
      final domains = WebsiteBlockStore.loadDomains();
      final auth = await resolveBlockingController().isAuthorized();
      if (!mounted) return;
      setState(() {
        _blocked = domains;
        _custom = WebsiteBlockStore.customDomainsOnly();
        _extensionActive = domains.isNotEmpty && auth;
      });
      return;
    }
    final status = await IosExtensionStatus.load();
    if (!mounted) return;
    setState(() {
      _blocked = WebsiteBlockStore.loadDomains();
      _custom = WebsiteBlockStore.customDomainsOnly();
      _extensionActive = status.safariContentBlocker;
    });
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncDomains() async {
    if (Platform.isIOS) {
      await IosRulesExportService.exportNow();
    }
    await BlockScheduleEnforcementService.syncPlatformEnforcement(force: true);
  }

  Future<void> _addCustom() async {
    if (_saving) return;
    final raw = _customCtrl.text;
    final norm = WebsiteBlockStore.normalizeDomain(raw);
    if (norm == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('도메인 형식을 확인해 주세요 (예: news.example.com)')),
      );
      return;
    }
    setState(() => _saving = true);
    await WebsiteBlockStore.addCustomDomain(raw);
    await _syncDomains();
    _customCtrl.clear();
    if (!mounted) return;
    final rejected = !WebsiteBlockStore.loadDomains().contains(norm);
    setState(() {
      _blocked = WebsiteBlockStore.loadDomains();
      _custom = WebsiteBlockStore.customDomainsOnly();
      _saving = false;
    });
    if (rejected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 도메인은 차단할 수 없어요 (Isle 재생 보호를 위해 제외됨)')),
      );
    }
  }

  Future<void> _removeCustom(String domain) async {
    if (_saving) return;
    if (RuleRemovalLock.removalBlocked) {
      if (!mounted) return;
      showRuleRemovalBlockedSnackBar(context);
      return;
    }
    setState(() => _saving = true);
    await WebsiteBlockStore.removeDomain(domain);
    await _syncDomains();
    if (!mounted) return;
    setState(() {
      _blocked = WebsiteBlockStore.loadDomains();
      _custom = WebsiteBlockStore.customDomainsOnly();
      _saving = false;
    });
  }

  Future<void> _toggle(String domain) async {
    if (_saving) return;
    final isRemoving = _blocked.contains(domain);
    if (isRemoving && RuleRemovalLock.removalBlocked) {
      if (!mounted) return;
      showRuleRemovalBlockedSnackBar(context);
      return;
    }
    setState(() => _saving = true);
    await WebsiteBlockStore.toggle(domain);
    await _syncDomains();
    if (!mounted) return;
    final rejected = !isRemoving && !WebsiteBlockStore.loadDomains().contains(domain);
    setState(() {
      _blocked = WebsiteBlockStore.loadDomains();
      _saving = false;
    });
    if (rejected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 도메인은 차단할 수 없어요 (Isle 재생 보호를 위해 제외됨)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('웹사이트 차단', style: IsleText.subtitle(color: IsleColors.ocean900)),
            const SizedBox(width: 8),
            _SafariOnlyChip(active: _extensionActive, isAndroid: Platform.isAndroid),
          ],
        ),
        const SizedBox(height: 6),
        _LimitationBanner(isAndroid: Platform.isAndroid),
        const SizedBox(height: 8),
        ...WebsiteBlockStore.catalog.map((def) => _SiteTile(
              def: def,
              blocked: _blocked.contains(def.domain),
              onToggle: _saving ? null : () => _toggle(def.domain),
            )),
        const SizedBox(height: 12),
        Text('직접 추가', style: IsleText.body(color: IsleColors.ocean700)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customCtrl,
                decoration: const InputDecoration(
                  hintText: '예: shorts.kakao.com',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addCustom(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _addCustom,
              child: const Text('추가'),
            ),
          ],
        ),
        if (_custom.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in _custom)
                InputChip(
                  label: Text(d, style: IsleText.caption()),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: _saving ? null : () => _removeCustom(d),
                ),
            ],
          ),
        ],
        if (!_extensionActive && Platform.isIOS) ...[
          const SizedBox(height: 4),
          _ExtensionSetupTile(),
        ],
      ],
    );
  }
}

class _SafariOnlyChip extends StatelessWidget {
  const _SafariOnlyChip({required this.active, required this.isAndroid});
  final bool active;
  final bool isAndroid;

  @override
  Widget build(BuildContext context) {
    final label = isAndroid
        ? (active ? 'VPN 차단 활성' : '전 브라우저 VPN')
        : (active ? 'Safari 확장 활성' : 'Safari 전용');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (active ? IsleColors.ocean500 : IsleColors.muted).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (active ? IsleColors.ocean500 : IsleColors.muted).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle_outline : Icons.info_outline,
            size: 12,
            color: active ? IsleColors.ocean500 : IsleColors.muted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: IsleText.caption(color: active ? IsleColors.ocean500 : IsleColors.muted)
                .copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _LimitationBanner extends StatelessWidget {
  const _LimitationBanner({required this.isAndroid});
  final bool isAndroid;

  @override
  Widget build(BuildContext context) {
    final text = isAndroid
        ? 'Android는 로컬 VPN(DNS)으로 Chrome 등 전 브라우저에서 차단됩니다. '
            'DoH 브라우저·VPN 끄기로 우회될 수 있어요.'
        : 'Safari에서만 차단됩니다. Chrome · 기타 브라우저는 iOS 제약으로 Isle에서 막을 수 없습니다.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: IsleColors.gold500.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IsleColors.gold500.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: IsleColors.gold500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: IsleText.caption(color: IsleColors.ocean900).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SiteTile extends StatelessWidget {
  const _SiteTile({
    required this.def,
    required this.blocked,
    required this.onToggle,
  });

  final WebsiteDef def;
  final bool blocked;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: blocked
              ? IsleColors.danger.withValues(alpha: 0.35)
              : IsleColors.ocean100,
        ),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        title: Text(def.label, style: IsleText.body()),
        subtitle: Text(def.note, style: IsleText.caption(color: IsleColors.muted)),
        value: blocked,
        activeThumbColor: IsleColors.danger,
        onChanged: onToggle != null ? (_) => onToggle!() : null,
      ),
    );
  }
}

class _ExtensionSetupTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IsleColors.ocean100.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.extension_outlined, size: 18, color: IsleColors.ocean700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Safari 확장 미활성', style: IsleText.body()),
                Text(
                  '설정 → Safari → 확장 프로그램 → Isle Content Blocker 켜기',
                  style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          const TextButton(
            onPressed: IosExtensionStatus.openSafariSettings,
            child: Text('이동'),
          ),
        ],
      ),
    );
  }
}
