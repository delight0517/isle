import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/safe_browser/page_link_harvest_service.dart';
import '../../../../shared/widgets/isle_sheet.dart';
import '../../../feed/providers/feed_provider.dart';
import '../../../../core/youtube/blocked_channel_store.dart';
import '../../../../core/youtube/blocked_url_store.dart';
import '../../../../core/youtube/content_filter_store.dart';

/// 인앱 Safari — 현재 페이지 링크 수집 후 일괄 차단
Future<PageLinkBulkBlockResult?> showPageLinkBulkBlockSheet({
  required BuildContext context,
  required WebViewController controller,
  required String pageUrl,
}) {
  return showIsleModalSheet<PageLinkBulkBlockResult>(
    context: context,
    builder: (ctx) => _PageLinkBulkBlockBody(
      controller: controller,
      pageUrl: pageUrl,
    ),
  );
}

class _PageLinkBulkBlockBody extends ConsumerStatefulWidget {
  const _PageLinkBulkBlockBody({
    required this.controller,
    required this.pageUrl,
  });

  final WebViewController controller;
  final String pageUrl;

  @override
  ConsumerState<_PageLinkBulkBlockBody> createState() => _PageLinkBulkBlockBodyState();
}

class _PageLinkBulkBlockBodyState extends ConsumerState<_PageLinkBulkBlockBody> {
  bool _loading = true;
  String? _error;
  List<PageLinkDomainGroup> _groups = const [];
  final Set<String> _selectedHosts = {};
  bool _blockDomains = true;
  bool _blockUrls = true;
  bool _blockKeywords = false;
  bool _blockYoutubeChannels = true;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _harvest();
  }

  String? get _pageHost {
    final host = Uri.tryParse(widget.pageUrl)?.host;
    if (host == null) return null;
    return host.replaceFirst(RegExp(r'^www\.'), '').toLowerCase();
  }

  Future<void> _harvest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final links = await PageLinkHarvestService.harvestFrom(widget.controller);
      if (!mounted) return;
      final groups = PageLinkHarvestService.groupByDomain(
        links,
        excludePageHost: _pageHost,
      );
      setState(() {
        _groups = groups;
        _selectedHosts
          ..clear()
          ..addAll(groups.map((g) => g.host));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '링크를 읽지 못했어요. 페이지가 완전히 로드된 뒤 다시 시도해 주세요.';
        _loading = false;
      });
    }
  }

  int get _selectedLinkCount => _groups
      .where((g) => _selectedHosts.contains(g.host))
      .fold<int>(0, (sum, g) => sum + g.count);

  Future<void> _apply() async {
    final selected = _groups.where((g) => _selectedHosts.contains(g.host)).toList();
    if (selected.isEmpty) return;

    setState(() => _applying = true);
    try {
      final result = await PageLinkHarvestService.applyBulk(
        selectedGroups: selected,
        blockDomains: _blockDomains,
        blockUrls: _blockUrls,
        blockKeywords: _blockKeywords,
        blockYoutubeChannels: _blockYoutubeChannels,
      );
      if (!mounted) return;
      await ref.read(blockedChannelsProvider.notifier).reload();
      await ref.read(blockedKeywordsProvider.notifier).reload();
      await ref.read(blockedUrlsProvider.notifier).reload();
      ref.invalidate(feedProvider);
      if (!mounted) return;
      Navigator.pop(context, result);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('이 페이지 링크 차단', style: IsleText.subtitle()),
          const SizedBox(height: 6),
          Text(
            '현재 페이지의 바로가기·본문 URL을 모아서 '
            'Safari·Isle 검색·YouTube에 일괄 추가합니다.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!, style: IsleText.body(color: IsleColors.danger))
          else if (_groups.isEmpty)
            Text(
              '외부 링크를 찾지 못했어요.\n스크롤해서 목록을 모두 불러온 뒤 다시 시도해 보세요.',
              style: IsleText.body(color: IsleColors.muted),
            )
          else ...[
            Text(
              '${_groups.length}개 사이트 · $_selectedLinkCount개 링크 선택됨',
              style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _OptionTile(
              label: 'Safari 사이트 차단 (도메인)',
              subtitle: '시스템 Safari에서 해당 사이트 열기 차단',
              value: _blockDomains,
              onChanged: (v) => setState(() => _blockDomains = v),
            ),
            _OptionTile(
              label: 'URL 차단',
              subtitle: 'Isle·YouTube·구글 검색에서 링크 숨김',
              value: _blockUrls,
              onChanged: (v) => setState(() => _blockUrls = v),
            ),
            _OptionTile(
              label: '검색 키워드 (도메인 stem)',
              subtitle: '피드·검색 제목 매칭 — 오탐 주의',
              value: _blockKeywords,
              onChanged: (v) => setState(() => _blockKeywords = v),
            ),
            _OptionTile(
              label: 'YouTube 채널 (@handle)',
              subtitle: '링크에 /@채널 이 있으면 채널 차단',
              value: _blockYoutubeChannels,
              onChanged: (v) => setState(() => _blockYoutubeChannels = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _selectedHosts.addAll(_groups.map((g) => g.host))),
                  child: const Text('전체 선택'),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedHosts.clear()),
                  child: const Text('전체 해제'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _harvest,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('다시 읽기'),
                ),
              ],
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.32,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _groups.length,
                itemBuilder: (context, i) {
                  final g = _groups[i];
                  final checked = _selectedHosts.contains(g.host);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedHosts.add(g.host);
                        } else {
                          _selectedHosts.remove(g.host);
                        }
                      });
                    },
                    title: Text(g.host, style: IsleText.body()),
                    subtitle: Text('링크 ${g.count}개', style: IsleText.caption(color: IsleColors.muted)),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: IsleSize.minTouchTarget,
            child: FilledButton.icon(
              onPressed: _applying || _loading || _groups.isEmpty || _selectedHosts.isEmpty
                  ? null
                  : _apply,
              icon: _applying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.block),
              label: Text(_applying ? '차단 중…' : '선택 항목 차단'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label, style: IsleText.body()),
      subtitle: Text(subtitle, style: IsleText.caption(color: IsleColors.muted)),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
