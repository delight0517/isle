import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/isle_sheet.dart';
import '../../../../core/utils/youtube_paste_resolver.dart';
import '../../../../core/youtube/blocked_channel_store.dart';
import '../../../../core/youtube/content_filter_store.dart';
import '../../providers/feed_provider.dart';

/// 링크 붙여넣기 → **이 채널 숨기기** | **이 영상만 숨기기**
Future<void> showBlockFromLinkSheet(BuildContext context, {String initialUrl = ''}) {
  return showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => _BlockFromLinkBody(initialUrl: initialUrl),
  );
}

class _BlockFromLinkBody extends ConsumerStatefulWidget {
  final String initialUrl;

  const _BlockFromLinkBody({required this.initialUrl});

  @override
  ConsumerState<_BlockFromLinkBody> createState() => _BlockFromLinkBodyState();
}

class _BlockFromLinkBodyState extends ConsumerState<_BlockFromLinkBody> {
  late final TextEditingController _urlCtrl;
  YoutubePasteInfo? _info;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final info = await YoutubePasteResolver.resolve(_urlCtrl.text);
      setState(() {
        _info = info;
        if (!info.valid) _error = info.errorMessage;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _blockChannel(YoutubePasteInfo info) async {
    final id = info.channelIdForStore;
    final name = (info.channelName ?? '').trim();
    if (id.isEmpty && name.isEmpty) return;
    await ref.read(blockedChannelsProvider.notifier).blockChannel(
          channelId: id.isNotEmpty ? id : name,
          channelName: name.isNotEmpty ? name : id,
        );
    ref.invalidate(feedProvider);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 채널을 숨겼어요')),
      );
    }
  }

  Future<void> _blockVideoOnly(YoutubePasteInfo info) async {
    final vid = info.videoId;
    if (vid == null || vid.length != 11) return;
    await ref.read(blockedVideosProvider.notifier).addVideo(vid, sourceUrl: info.sourceUrl);
    ref.invalidate(feedProvider);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 영상만 숨겼어요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('링크로 숨기기', style: IsleText.subtitle()),
            const SizedBox(height: 8),
            Text(
              '영상 링크를 붙여넣고 아래에서만 고르세요.',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'YouTube 링크',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _analyze(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _analyze,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search),
              label: Text(_loading ? '분석 중…' : '링크 분석'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: IsleText.caption(color: IsleColors.danger)),
            ],
            if (_info != null && _info!.valid) ...[
              const SizedBox(height: 20),
              Text(_info!.title ?? '', style: IsleText.body().copyWith(fontWeight: FontWeight.w600), maxLines: 2),
              if ((_info!.channelName ?? '').isNotEmpty)
                Text('채널: ${_info!.channelName}', style: IsleText.caption(color: IsleColors.muted)),
              const SizedBox(height: 16),
              if (_info!.canBlockChannel)
                FilledButton(
                  onPressed: () => _blockChannel(_info!),
                  style: FilledButton.styleFrom(backgroundColor: IsleColors.danger),
                  child: const Text('이 채널 영상 전부 숨기기'),
                ),
              if (_info!.canBlockChannel && _info!.canBlockThisVideo) const SizedBox(height: 10),
              if (_info!.canBlockThisVideo)
                OutlinedButton(
                  onPressed: () => _blockVideoOnly(_info!),
                  child: const Text('이 영상만 숨기기'),
                ),
              if (!_info!.canBlockChannel && !_info!.canBlockThisVideo)
                Text('숨길 수 있는 정보가 부족해요.', style: IsleText.caption(color: IsleColors.muted)),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final clip = await Clipboard.getData('text/plain');
                if (clip?.text != null) _urlCtrl.text = clip!.text!.trim();
              },
              child: const Text('클립보드에서 붙여넣기'),
            ),
          ],
        ),
      ),
    );
  }
}
