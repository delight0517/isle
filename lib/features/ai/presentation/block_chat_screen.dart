import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/ai_config_store.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/ai/block_chat/block_chat_executor.dart';
import '../../../core/ai/block_chat/block_chat_models.dart';
import '../../../core/ai/block_chat/block_chat_parser.dart';
import '../../../core/block_schedule/block_schedule_store.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/youtube/content_filter_store.dart';
import '../../../features/feed/providers/feed_provider.dart';
import '../../../shared/widgets/isle_app_bar.dart';

const _examplePrompts = [
  '매일 10시30분까지 isle 유튜브 차단해줘',
  '매일 9시까지 Safari 막아줘 (Isle 웹도)',
  '인스타 5분 쓰고 10분 쉬기, 하루 10분',
  '숏츠 숨겨줘',
  '유튜브 하루 20분 한도',
];

/// API 챗 — 자연어로 차단·한도 설정
class BlockChatScreen extends ConsumerStatefulWidget {
  const BlockChatScreen({super.key});

  @override
  ConsumerState<BlockChatScreen> createState() => _BlockChatScreenState();
}

class _BlockChatScreenState extends ConsumerState<BlockChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  int _configTick = 0;
  final _messages = <BlockChatMessage>[
    const BlockChatMessage(
      role: BlockChatRole.assistant,
      text: '차단·한도를 말로 설정해 보세요.\n\n'
          '적용되면 초록 카드가 뜨고, 탭하면 해당 설정 화면으로 이동해요.\n'
          '스케줄 제거는 타임락이 켜져 있으면 대기가 시작됩니다.',
    ),
  ];
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refreshAfterApply(BlockChatPlan plan) async {
    switch (plan.action) {
      case 'add_keyword':
      case 'remove_keyword':
        await ref.read(blockedKeywordsProvider.notifier).reload();
        ref.invalidate(feedProvider);
      case 'morning_schedule':
      case 'app_session_limit':
      case 'remove_schedule':
        await ref.read(blockSchedulesProvider.notifier).reload();
    }
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _ctrl.text).trim();
    if (text.isEmpty || _busy) return;
    HapticFeedback.lightImpact();
    _ctrl.clear();
    setState(() {
      _busy = true;
      _messages.add(BlockChatMessage(role: BlockChatRole.user, text: text));
      _messages.add(
        const BlockChatMessage(
          role: BlockChatRole.assistant,
          text: '설정을 분석하는 중…',
          isLoading: true,
        ),
      );
    });
    _scrollToEnd();

    final (plan, usedAi) = await BlockChatParser.parse(text);
    final result = await BlockChatExecutor.apply(plan);
    if (!result.isFailure) {
      await _refreshAfterApply(plan);
    }

    if (!mounted) return;
    setState(() {
      _messages.removeLast();
      _messages.add(
        BlockChatMessage(
          role: BlockChatRole.assistant,
          text: _formatReply(plan, result, usedAi),
          result: result,
        ),
      );
      _busy = false;
    });
    _scrollToEnd();
  }

  String _formatReply(BlockChatPlan plan, BlockChatResult result, bool usedAi) {
    final buf = StringBuffer(result.summary);
    if (!result.isFailure) {
      if (usedAi && AiConfigStore.isConfigured) {
        buf.write('\n\n(AI로 해석했어요)');
      } else if (!usedAi) {
        buf.write('\n\n(로컬 규칙으로 해석했어요 — API 키 있으면 더 유연해요)');
      }
    }
    if (result.needsUnlockWait && result.unlockMinutes != null) {
      buf.write('\n\n⏳ 타임락: ${result.unlockMinutes}분 후 편집 창에서 해제할 수 있어요.');
    }
    if (!result.isFailure && plan.reply.isNotEmpty && plan.reply != result.summary) {
      buf.write('\n${plan.reply}');
    }
    return buf.toString().trim();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: IsleColors.sand100,
      appBar: const IsleAppBar(title: '차단 AI 챗'),
      body: Column(
        children: [
          Builder(
            key: ValueKey(_configTick),
            builder: (_) {
              final configured = AiConfigStore.isConfigured;
              final budgetOk = !IsleUserDefaults.apiBudgetEnforced ||
                  IsleUserDefaults.apiMonthlyBudgetUsd >= 0.5;
              if (configured && budgetOk) {
                return Material(
                  color: const Color(0xFFE8F5E9),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                    title: Text(
                      'AI 연결됨 — ${AiConfigStore.activeProvider.displayName}',
                      style: IsleText.caption(color: const Color(0xFF1B5E20)),
                    ),
                  ),
                );
              }
              return Material(
                color: const Color(0xFFFFF8E1),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.key_off, color: Colors.orange),
                  title: Text(
                    configured
                        ? '예산 \$0 — AI 센터에서 예산을 \$1 이상으로'
                        : 'API 없음 — 스케줄·한도는 로컬 규칙으로 동작',
                    style: IsleText.caption(color: Colors.orange.shade900),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      await context.push('/settings/ai-hub');
                      if (mounted) setState(() => _configTick++);
                    },
                    child: const Text('AI 센터'),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length + 1,
              itemBuilder: (_, i) {
                if (i == _messages.length) {
                  return _ExampleChips(
                    busy: _busy,
                    onTap: _send,
                  );
                }
                return _Bubble(message: _messages[i]);
              },
            ),
          ),
          Material(
            elevation: 8,
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottom),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _busy ? null : (_) => _send(),
                      decoration: InputDecoration(
                        hintText: '예: 매일 9시까지 Safari 차단…',
                        filled: true,
                        fillColor: IsleColors.ocean100.withValues(alpha: 0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : () => _send(),
                    icon: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleChips extends StatelessWidget {
  const _ExampleChips({required this.busy, required this.onTap});

  final bool busy;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in _examplePrompts)
            ActionChip(
              label: Text(p, style: IsleText.caption()),
              onPressed: busy ? null : () => onTap(p),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final BlockChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == BlockChatRole.user;
    final isError = message.result?.isFailure == true;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isUser
        ? IsleColors.ocean500
        : isError
            ? const Color(0xFFFFEBEE)
            : Colors.white;
    final fg = isUser
        ? Colors.white
        : isError
            ? const Color(0xFFB71C1C)
            : IsleColors.ocean900;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.88,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isUser ? const Radius.circular(4) : null,
                bottomLeft: isUser ? null : const Radius.circular(4),
              ),
              border: isError ? Border.all(color: const Color(0xFFEF9A9A)) : null,
              boxShadow: isUser || isError
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: message.isLoading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(message.text, style: IsleText.body(color: fg)),
                    ],
                  )
                : Text(
                    message.text,
                    style: IsleText.body(color: fg).copyWith(height: 1.45),
                  ),
          ),
          if (message.result != null &&
              !message.result!.isFailure &&
              message.result!.steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...message.result!.steps.map((s) => _AppliedCard(step: s)),
          ],
        ],
      ),
    );
  }
}

class _AppliedCard extends StatelessWidget {
  const _AppliedCard({required this.step});

  final BlockChatAppliedStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    step.title,
                    style: IsleText.body().copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(step.detail, style: IsleText.caption(color: IsleColors.muted)),
            if (step.route != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: IsleSize.minTouchTarget - 8,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(step.route!),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(step.routeLabel ?? '설정 열기'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
