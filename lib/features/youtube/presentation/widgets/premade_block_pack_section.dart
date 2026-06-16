import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/block/models/premade_block_pack.dart';
import '../../../../core/block/premade_block_pack_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/youtube/blocked_channel_store.dart';
import '../../../../core/youtube/blocked_url_store.dart';
import '../../../../core/youtube/content_filter_store.dart';
import '../../../feed/providers/feed_provider.dart';

/// 4VPN PremadeBlockPacks — 원클릭 채널·키워드·URL·사이트 일괄 차단
class PremadeBlockPackSection extends ConsumerStatefulWidget {
  const PremadeBlockPackSection({super.key});

  @override
  ConsumerState<PremadeBlockPackSection> createState() =>
      _PremadeBlockPackSectionState();
}

class _PremadeBlockPackSectionState extends ConsumerState<PremadeBlockPackSection> {
  List<PremadeBlockPack>? _packs;
  String? _applyingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final packs = await PremadeBlockPackService.loadCatalog();
    if (!mounted) return;
    setState(() => _packs = packs);
  }

  Future<void> _apply(PremadeBlockPack pack) async {
    final sensitive = pack.packId.contains('adult');
    if (sensitive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('「${pack.displayName}」 적용'),
          content: Text(
            '${pack.entryCount}개 규칙을 한 번에 추가합니다.\n\n'
            '· YouTube 채널 / 검색·피드 키워드 / URL\n'
            '· Safari 사이트(해당 팩에 포함 시)\n\n'
            '이미 있는 항목은 건너뜁니다.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('가져오기')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _applyingId = pack.packId);
    try {
      final result = await PremadeBlockPackService.applyPack(pack.packId);
      if (!mounted) return;
      await ref.read(blockedChannelsProvider.notifier).reload();
      await ref.read(blockedKeywordsProvider.notifier).reload();
      await ref.read(blockedUrlsProvider.notifier).reload();
      await ref.read(feedProvider.notifier).removeBlockedFromFeed();
      messenger.showSnackBar(
        SnackBar(content: Text(result.summary(pack.displayName))),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('팩 적용 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _applyingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packs = _packs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('프리셋 차단 팩', style: IsleText.subtitle()),
        const SizedBox(height: 6),
        Text(
          '버튼 한 번 — 채널·키워드·URL·검색 결과까지 일괄 추가. '
          'YouTube 검색·피드·구글·Isle 피드에 적용됩니다.',
          style: IsleText.caption(color: IsleColors.muted),
        ),
        const SizedBox(height: 12),
        if (packs == null)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (packs.isEmpty)
          Text('팩을 불러오지 못했어요', style: IsleText.body(color: IsleColors.muted))
        else
          ...packs.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PackCard(
                  pack: p,
                  applying: _applyingId == p.packId,
                  applied: PremadeBlockPackService.isPackApplied(p.packId),
                  onApply: () => _apply(p),
                ),
              )),
      ],
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.applying,
    required this.applied,
    required this.onApply,
  });

  final PremadeBlockPack pack;
  final bool applying;
  final bool applied;
  final VoidCallback onApply;

  IconData get _icon {
    if (pack.packId.contains('adult')) return Icons.visibility_off;
    if (pack.packId.contains('gaming')) return Icons.sports_esports_outlined;
    return Icons.shield_outlined;
  }

  Color get _accent {
    if (pack.packId.contains('adult')) return IsleColors.danger;
    if (pack.packId.contains('gaming')) return IsleColors.ocean700;
    return IsleColors.ocean500;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icon, color: _accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pack.displayName,
                              style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (applied)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: IsleColors.ocean100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '적용됨',
                                style: IsleText.caption(color: IsleColors.ocean700),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${pack.entryCount}개 · ${pack.description}',
                        style: IsleText.caption(color: IsleColors.muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: IsleSize.minTouchTarget,
              child: FilledButton.icon(
                onPressed: applying ? null : onApply,
                icon: applying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_outlined, size: 20),
                label: Text(applying ? '적용 중…' : '가져오기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
