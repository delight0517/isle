import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/utils/isle_keyboard.dart';
import '../../../../core/youtube/blocked_channel_store.dart';
import '../../../../core/constants/app_build_config.dart';
import '../../../../core/youtube/channel_genre_ai_service.dart';
import '../../../../core/youtube/channel_genre_block_store.dart';
import '../../../../shared/widgets/copy_text_row.dart';
import '../../../../shared/widgets/isle_sheet.dart';

class BlockChannelSheetResult {
  final bool channelBlocked;
  final GenreApplyResult? genreApply;

  const BlockChannelSheetResult({required this.channelBlocked, this.genreApply});
}

/// 유튜브·피드 공통 차단 시트 — 링크 복사 · 확인 · 유형 차단
Future<BlockChannelSheetResult?> showBlockChannelSheet(
  BuildContext context, {
  required String channelId,
  required String channelName,
  String pageUrl = '',
}) {
  if (IsleUserDefaults.dismissKeyboardOnBlockSheet) {
    IsleKeyboard.hide();
  }

  return showIsleModalSheet<BlockChannelSheetResult>(
    context: context,
    builder: (ctx) => _BlockChannelSheetBody(
      initialChannelId: channelId,
      initialChannelName: channelName,
      pageUrl: pageUrl,
    ),
  );
}

class _BlockChannelSheetBody extends ConsumerStatefulWidget {
  final String initialChannelId;
  final String initialChannelName;
  final String pageUrl;

  const _BlockChannelSheetBody({
    required this.initialChannelId,
    required this.initialChannelName,
    required this.pageUrl,
  });

  @override
  ConsumerState<_BlockChannelSheetBody> createState() => _BlockChannelSheetBodyState();
}

class _BlockChannelSheetBodyState extends ConsumerState<_BlockChannelSheetBody> {
  late final TextEditingController _idCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _reasonCtrl;
  bool _blockSimilarType = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _idCtrl = TextEditingController(text: widget.initialChannelId);
    _nameCtrl = TextEditingController(text: widget.initialChannelName);
    _reasonCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => IsleKeyboard.hide());
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmBlock() async {
    IsleKeyboard.hide();
    final id = _idCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (id.isEmpty && name.isEmpty) return;

    final channelLabel = name.isNotEmpty ? name : id;
    IsleKeyboard.hide();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        IsleKeyboard.hide();
        return AlertDialog(
        title: const Text('채널 차단'),
        content: Text(
          '「$channelLabel」 유튜브 채널을 차단할까요?\n\n'
          '피드와 Isle 안 유튜브(WebView)에서 이 채널 영상이 숨겨집니다.\n'
          '※ iOS 「YouTube」앱은 OS가 막아 줄 수 없어요 — 차단 탭 → 항상 막기에서 YouTube 앱을 선택하면 앱 전체를 막을 수 있어요.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('아니요')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: IsleColors.danger),
            child: const Text('차단하기'),
          ),
        ],
        );
      },
    );
    IsleKeyboard.hide();
    if (ok != true || !mounted) return;

    setState(() => _saving = true);

    await ref.read(blockedChannelsProvider.notifier).blockChannel(
          channelId: id,
          channelName: name,
        );

    GenreApplyResult? genreResult;
    if (_blockSimilarType && AppBuildConfig.enableGenreBlockAi) {
      await ChannelGenreBlockStore.addSample(
        channelId: id,
        channelName: name,
        pageUrl: widget.pageUrl,
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      );

      if (IsleUserDefaults.genreBlockAutoAnalyze && ChannelGenreBlockStore.shouldRunAutoAnalyze) {
        final lang = ref.read(appLocaleProvider)?.languageCode ?? 'ko';
        genreResult = await ChannelGenreAiService.analyzeAndApply(ref, languageCode: lang);
      }
    }

    if (mounted) {
      Navigator.pop(
        context,
        BlockChannelSheetResult(channelBlocked: true, genreApply: genreResult),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final url = widget.pageUrl.trim();
    final sampleN = ChannelGenreBlockStore.sampleCount;
    final minN = IsleUserDefaults.genreBlockMinSamples;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('채널 차단', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          if (url.isNotEmpty) ...[
            CopyTextRow(label: '현재 링크 (탭하여 복사)', value: url),
            const SizedBox(height: 12),
          ],
          Text(
            _nameCtrl.text.isNotEmpty || widget.initialChannelName.isNotEmpty
                ? '이 페이지의 채널을 차단할 수 있어요.'
                : '채널명·ID를 확인한 뒤 차단하세요.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            readOnly: widget.initialChannelName.isNotEmpty,
            decoration: const InputDecoration(
              labelText: '채널명',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _idCtrl,
            decoration: const InputDecoration(
              labelText: '채널 ID (선택)',
              hintText: 'UC… 또는 @handle',
              border: OutlineInputBorder(),
            ),
          ),
          if (AppBuildConfig.enableGenreBlockAi) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('이 유형의 채널도 앞으로 차단'),
              subtitle: Text(
                '비슷한 주제·스타일 채널을 AI가 찾아 키워드·채널 목록으로 숨깁니다. '
                '샘플 $sampleN/$minN개 · Google 로그인 시 검색으로 더 많이 차단',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              value: _blockSimilarType,
              onChanged: (v) => setState(() => _blockSimilarType = v),
            ),
            if (_blockSimilarType) ...[
              TextField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(
                  labelText: '왜 이 유형을 싫어하나요? (선택)',
                  hintText: '예: 클릭베이트 쇼츠, 게임 실황, …',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
            ],
          ],
          FilledButton(
            onPressed: _saving ? null : _confirmBlock,
            style: FilledButton.styleFrom(backgroundColor: IsleColors.danger),
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('차단 확인'),
          ),
          TextButton(
            onPressed: () {
              IsleKeyboard.hide();
              Navigator.pop(context);
            },
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
}
