import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/explorer/safari_web_config.dart';
import '../../../core/localization/moa_strings.dart';
import '../../../core/platform/platform_block_intent.dart';
import '../../../core/platform/moa_four_vpn_rules_service.dart';
import '../../../core/navigation/link_router.dart';
import '../../../core/safe_browser/safe_browser_history_store.dart';
import '../../../core/safe_browser/safe_browser_temporary_allow_store.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// Safe Browser 허브 — QR · URL 입력 · 최근 기록
class SafeBrowserHubScreen extends StatefulWidget {
  const SafeBrowserHubScreen({super.key});

  @override
  State<SafeBrowserHubScreen> createState() => _SafeBrowserHubScreenState();
}

class _SafeBrowserHubScreenState extends State<SafeBrowserHubScreen> {
  List<SafeBrowserHistoryEntry> _history = const [];
  List<({String host, DateTime expiresAt})> _allows = const [];
  bool _fourVpnRulesEnabled = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    await SafeBrowserHistoryStore.ensureOpen();
    await SafeBrowserTemporaryAllowStore.ensureOpen();
    if (!mounted) return;
    if (MoaFourVpnRulesService.enabled) {
      try {
        await MoaFourVpnRulesService.refresh();
      } catch (_) {
        // Keep the last still-fresh cache; stale snapshots fail open.
      }
    }
    if (!mounted) return;
    setState(() {
      _history = SafeBrowserHistoryStore.loadAll().take(20).toList();
      _allows = SafeBrowserTemporaryAllowStore.listActive();
      _fourVpnRulesEnabled = MoaFourVpnRulesService.enabled;
    });
  }

  Future<void> _openUrl(String url) async {
    final route = LinkRouter.safeBrowserRoute(url);
    if (route == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('열 수 없는 주소예요')),
      );
      return;
    }
    await SafeBrowserHistoryStore.recordOpened(url);
    if (!mounted) return;
    context.push(route);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final strings = MoaStrings.of(context);
    final fourVpnSnapshot = MoaFourVpnRulesService.current();
    return Scaffold(
      backgroundColor: IsleColors.sand100,
      appBar: const IsleAppBar(title: '안전 브라우저'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, IsleSize.scrollBottomPadding(context)),
        children: [
          Text(
            PlatformBlockCopy.safeBrowserIntro,
            style: IsleText.body(color: IsleColors.muted),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: Text(strings.t('four_vpn_safari_title')),
                  subtitle: Text(strings.t('four_vpn_safari_description')),
                  value: _fourVpnRulesEnabled,
                  onChanged: (enabled) async {
                    final messenger = ScaffoldMessenger.of(context);
                    await MoaFourVpnRulesService.setEnabled(enabled);
                    if (!mounted) return;
                    if (enabled) {
                      var refreshed = false;
                      try {
                        refreshed = await MoaFourVpnRulesService.refresh();
                      } catch (_) {
                        // Explain the missing account or shared snapshot below.
                      }
                      if (!mounted) return;
                      if (!refreshed) {
                        messenger.showSnackBar(
                          SnackBar(
                            content:
                                Text(strings.t('four_vpn_safari_unavailable')),
                          ),
                        );
                      }
                    }
                    if (mounted) setState(() => _fourVpnRulesEnabled = enabled);
                  },
                ),
                if (_fourVpnRulesEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        fourVpnSnapshot == null
                            ? strings.t('four_vpn_safari_sync_missing')
                            : strings.t(
                                'four_vpn_safari_sync_status',
                                args: {
                                  'revision': '${fourVpnSnapshot.revision}',
                                  'count':
                                      '${fourVpnSnapshot.schedules.length}',
                                  'timeZone': fourVpnSnapshot.timeZone,
                                },
                              ),
                        style: IsleText.caption(color: IsleColors.muted),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/home/share/qr'),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('QR로 열기'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => SafariWebConfig.showUrlSheet(context),
            icon: const Icon(Icons.language),
            label: const Text('주소 입력해서 열기'),
          ),
          const SizedBox(height: 8),
          Text(
            '주소 모음·게시판 페이지에서는 ⋮ 메뉴 → 「이 페이지 링크 일괄 차단」으로 '
            'Firefox 콘솔 없이 링크를 모아 차단할 수 있어요.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push('/settings/default-browser'),
            icon: const Icon(Icons.open_in_browser),
            label: const Text('기본 브라우저로 설정'),
          ),
          if (_allows.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('임시 허용 중', style: IsleText.subtitle()),
            const SizedBox(height: 8),
            ..._allows.map(
              (a) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(a.host),
                subtitle: Text(
                  '~ ${TimeOfDay.fromDateTime(a.expiresAt).format(context)}까지',
                  style: IsleText.caption(),
                ),
              ),
            ),
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('최근 기록', style: IsleText.subtitle()),
            const SizedBox(height: 8),
            ..._history.map((e) {
              final icon = e.kind == SafeBrowserHistoryKind.blocked
                  ? Icons.block
                  : Icons.check_circle_outline;
              final color = e.kind == SafeBrowserHistoryKind.blocked
                  ? IsleColors.danger
                  : IsleColors.ocean700;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon, color: color, size: 20),
                title: Text(
                  e.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IsleText.caption(),
                ),
                subtitle: e.note != null
                    ? Text(e.note!,
                        style: IsleText.caption(color: IsleColors.muted))
                    : null,
                onTap: e.kind == SafeBrowserHistoryKind.opened
                    ? () => _openUrl(e.url)
                    : null,
              );
            }),
          ],
        ],
      ),
    );
  }
}
