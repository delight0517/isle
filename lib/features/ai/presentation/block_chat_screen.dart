import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/ai_config_store.dart';
import '../../../core/ai/block_chat/block_audit_log_store.dart';
import '../../../core/ai/block_chat/block_chat_daily_scenarios.dart';
import '../../../core/ai/block_chat/block_chat_executor.dart';
import '../../../core/ai/block_chat/block_chat_models.dart';
import '../../../core/ai/block_chat/block_chat_parser.dart';
import '../../../core/ai/block_chat/block_chat_persona_scenarios.dart';
import '../../../core/ai/block_chat/block_chat_preview.dart';
import '../../../core/ai/block_chat/block_chat_transcript_service.dart';
import '../../../core/ai/block_chat/block_chat_transcript_store.dart';
import '../../../core/block_schedule/block_schedule_store.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/navigation/schedule_overlay_navigation.dart';
import '../../../core/block/rule_pending_removal_service.dart';
import '../../../core/youtube/blocked_channel_store.dart';
import '../../../core/youtube/blocked_url_store.dart';
import '../../../core/youtube/content_filter_store.dart';
import '../../../features/feed/providers/feed_provider.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import 'widgets/block_chat_applied_panel.dart';
import 'widgets/block_chat_coach_panel.dart';
import 'widgets/block_chat_quick_reply_bar.dart';

/// API 챗 — 자연어로 차단·한도 설정
class BlockChatScreen extends ConsumerStatefulWidget {
  const BlockChatScreen({super.key, this.initialMessage});

  /// 진입 시 자동 전송할 메시지 (아침 차단 빠른 설정 등에서 사용)
  final String? initialMessage;

  @override
  ConsumerState<BlockChatScreen> createState() => _BlockChatScreenState();
}

class _BlockChatScreenState extends ConsumerState<BlockChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  int _configTick = 0;
  bool _showAiStatus = true;
  final _messages = <BlockChatMessage>[
    const BlockChatMessage(
      role: BlockChatRole.assistant,
      text: '처음부터 완벽하게 말하지 않아도 돼요.\n\n'
          '「유튜브 좀 줄이고 싶어」처럼 막연하게 말해도, '
          '지금 확실한 것만 먼저 제안하고 적용 뒤 다음 한 단계를 이어서 권유해요.\n'
          '아래 고민 칩을 눌러 보거나, 지금 불편한 상황을 그대로 써 주세요.\n\n'
          '✅ 바꿀 내용을 먼저 카드로 보여주고, 「확인 적용」을 눌러야 실제로 반영돼요.\n'
          '적용되면 타임라인·탭 위치·막히는 대상과 다음에 해볼 한 가지를 보여줘요.\n'
          '「스케줄 편집에서 확인」「차단 탭에서 보기」로 바로 이동할 수 있어요.\n\n'
          '⏳ 제거·해제 요청은 제거 타임락이 켜져 있으면 '
          '대기 시간이 끝난 뒤 자동으로 반영돼요.\n'
          '⚠️ Safari·iPhone 앱 차단은 Screen Time(또는 Android 접근성) 허용 후에야 실제로 막혀요.',
    ),
  ];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final msg = widget.initialMessage;
    if (msg != null && msg.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _send(msg);
      });
    }
  }

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
        await ref.read(rulePendingRemovalsProvider.notifier).refresh();
        ref.invalidate(feedProvider);
      case 'remove_url':
      case 'block_url':
        await ref.read(blockedUrlsProvider.notifier).reload();
        if (plan.action == 'remove_url') {
          await ref.read(rulePendingRemovalsProvider.notifier).refresh();
        }
        ref.invalidate(feedProvider);
      case 'block_channel':
        await BlockedChannelStore.ensureOpen();
        await ref.read(blockedChannelsProvider.notifier).reload();
        ref.invalidate(feedProvider);
      case 'morning_schedule':
      case 'allow_window':
      case 'morning_habit_pack':
      case 'music_foreground_limit':
      case 'app_session_limit':
      case 'night_schedule':
      case 'remove_schedule':
      case 'relax_block':
        await ref.read(blockSchedulesProvider.notifier).reload();
      case 'youtube_limit':
      case 'platform_limit':
        ref.invalidate(feedProvider);
      case 'persona_bundle':
        await ref.read(blockSchedulesProvider.notifier).reload();
        await ref.read(blockedKeywordsProvider.notifier).reload();
        await ref.read(blockedUrlsProvider.notifier).reload();
        await BlockedChannelStore.ensureOpen();
        await ref.read(blockedChannelsProvider.notifier).reload();
        ref.invalidate(feedProvider);
      default:
        break;
    }
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _ctrl.text).trim();
    if (text.isEmpty || _busy) return;
    final contextPlan = _latestContextPlan();
    HapticFeedback.lightImpact();
    _ctrl.clear();
    setState(() {
      _busy = true;
      _messages.add(
        BlockChatMessage(
          role: BlockChatRole.user,
          text: text,
          createdAt: DateTime.now(),
        ),
      );
      _messages.add(
        const BlockChatMessage(
          role: BlockChatRole.assistant,
          text: '설정을 분석하는 중…',
          isLoading: true,
        ),
      );
    });
    _scrollToEnd();

    // 파싱은 한 번만(=API도 한 번). 확인 카드를 거쳐 적용은 사용자가 누른 뒤.
    final (plan, usedAi) = await BlockChatParser.parseWithContext(
      text,
      previousPlan: contextPlan,
    );
    if (!mounted) return;

    // 정보성(explain 등) — 확인 없이 바로 답만 보여준다.
    if (BlockChatPreview.isInfoOnly(plan.action)) {
      final infoReply = plan.reply.isNotEmpty ? plan.reply : '도움이 필요한 설정을 말씀해 주세요.';
      setState(() {
        _messages.removeLast();
        _messages.add(
          BlockChatMessage(
            role: BlockChatRole.assistant,
            text: infoReply,
            plan: plan,
            usedAi: usedAi,
            createdAt: DateTime.now(),
          ),
        );
        _busy = false;
      });
      unawaited(_logTranscript(
        userText: text,
        assistantText: infoReply,
        plan: plan,
        outcome: 'info_only',
      ));
      _scrollToEnd();
      return;
    }

    // 미리보기 카드 — 확인을 누르면 _confirmPlan에서 실제 적용.
    setState(() {
      _messages.removeLast();
      _messages.add(
        BlockChatMessage(
          role: BlockChatRole.assistant,
          text: BlockChatPreview.headline(plan),
          plan: plan,
          usedAi: usedAi,
          awaitingConfirm: true,
          createdAt: DateTime.now(),
        ),
      );
      _busy = false;
    });
    _scrollToEnd();
  }

  BlockChatPlan? _latestContextPlan() {
    for (final message in _messages.reversed) {
      if (message.isLoading) continue;
      if (message.role == BlockChatRole.assistant && message.plan != null) {
        return message.plan;
      }
    }
    return null;
  }

  /// 미리보기 카드의 「확인」 — 여기서 처음으로 상태를 바꾼다.
  Future<void> _confirmPlan(BlockChatMessage preview) async {
    final plan = preview.plan;
    if (plan == null || _busy) return;
    final idx = _messages.indexOf(preview);
    if (idx < 0) return;
    final rawCommand = idx > 0 && _messages[idx - 1].role == BlockChatRole.user
        ? _messages[idx - 1].text
        : preview.text;
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _messages[idx] = const BlockChatMessage(
        role: BlockChatRole.assistant,
        text: '적용하는 중…',
        isLoading: true,
      );
    });
    _scrollToEnd();

    final result = await BlockChatExecutor.apply(plan, ref: ref);
    if (!result.isFailure) {
      await _refreshAfterApply(plan);
    }
    unawaited(_logToAudit(rawCommand: rawCommand, plan: plan, result: result));
    final replyText = _formatReply(plan, result, preview.usedAi ?? false);
    unawaited(_logTranscript(
      userText: rawCommand,
      assistantText: replyText,
      plan: plan,
      outcome: result.isFailure ? 'failed' : 'applied',
    ));
    if (!mounted) return;

    if (!result.isFailure && result.permissionGaps.isNotEmpty) {
      final first = result.permissionGaps.first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '스케줄은 저장됐어요. ${first.title} — ${first.actionLabel ?? first.routeLabel}',
          ),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: '열기',
            onPressed: () => pushRoutePreferRoot(context, first.route),
          ),
        ),
      );
    }
    setState(() {
      final at = _messages.indexWhere((m) => m.isLoading);
      final msg = BlockChatMessage(
        role: BlockChatRole.assistant,
        text: replyText,
        result: result,
        plan: plan,
        usedAi: preview.usedAi,
        createdAt: DateTime.now(),
      );
      if (at >= 0) {
        _messages[at] = msg;
      } else {
        _messages.add(msg);
      }
      _busy = false;
    });
    _scrollToEnd();
  }

  /// 받은 명령·적용 결과 요약 기록 (14일 보관 · action/summary/steps만 — 원문 대화는 [_logTranscript] 참고)
  Future<void> _logToAudit({
    required String rawCommand,
    required BlockChatPlan plan,
    required BlockChatResult result,
  }) async {
    try {
      await BlockAuditLogStore.ensureOpen();
      await BlockAuditLogStore.record(
        command: rawCommand,
        action: plan.action,
        summary: result.summary,
        steps: result.steps.map((s) => '${s.title}: ${s.detail}').toList(),
        success: !result.isFailure,
      );
    } catch (_) {}
  }

  /// 실제 대화 원문(사용자 발화+AI 응답 전문) 7일 보관 — 디버깅 시뮬레이터가
  /// 같은 store를 써서, 실사용 채팅과 시뮬레이션 실행 기록이 한 곳에서 함께
  /// 조회된다(2026-07-20 사용자 요청).
  Future<void> _logTranscript({
    required String userText,
    required String assistantText,
    BlockChatPlan? plan,
    required String outcome,
  }) async {
    try {
      await BlockChatTranscriptStore.ensureOpen();
      await BlockChatTranscriptStore.recordTurn(
        userText: userText,
        assistantText: assistantText,
        plan: plan,
        outcome: outcome,
      );
    } catch (_) {}
  }

  /// 미리보기 카드의 「취소」 — 적용하지 않고 카드만 닫는다.
  void _cancelPlan(BlockChatMessage preview) {
    final idx = _messages.indexOf(preview);
    if (idx < 0) return;
    HapticFeedback.selectionClick();
    final idxBefore = _messages.indexOf(preview) - 1;
    final userText = idxBefore >= 0 && _messages[idxBefore].role == BlockChatRole.user
        ? _messages[idxBefore].text
        : preview.text;
    unawaited(_logTranscript(
      userText: userText,
      assistantText: '취소했어요. 바꾸고 싶은 내용을 다시 말씀해 주세요.',
      plan: preview.plan,
      outcome: 'cancelled',
    ));
    setState(() {
      _messages[idx] = const BlockChatMessage(
        role: BlockChatRole.assistant,
        text: '취소했어요. 바꾸고 싶은 내용을 다시 말씀해 주세요.',
      );
    });
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
    if (result.permissionGaps.isNotEmpty) {
      buf.write(
        '\n\n⚠️ OS 차단 권한·앱 선택이 필요해요 — 아래 빨간 카드에서 허용하면 실제로 막혀요.',
      );
    } else if (result.removalScheduledAuto) {
      buf.write(
        '\n\n⏳ 타임락 대기 후 자동 적용 — 추가로 누르지 않아도 반영돼요.',
      );
    } else if (result.needsUnlockWait && result.unlockMinutes != null) {
      buf.write(
        '\n\n⏳ 스케줄 타임락: ${result.unlockMinutes}분 후 편집 창이 열리면 자동으로 꺼져요.',
      );
    }
    if (!result.isFailure &&
        plan.reply.isNotEmpty &&
        plan.reply != result.summary) {
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

  /// SUGGEST 칩 탭 — 캔드 로컬 답변만 표시, 재파싱·API 호출 없음(CHAT_SPEC SUGGEST).
  /// 확인 질문(explain) 아래 버튼 탭 — `__info__:` 접두어면 재파싱 없이 안내
  /// 문구만 보여주고(예: "조금 더 세부적으로…"), 그 외에는 사용자가 그 문장을
  /// 직접 친 것처럼 다시 파싱·적용한다.
  void _handleQuickReply(String value) {
    const infoPrefix = '__info__:';
    if (value.startsWith(infoPrefix)) {
      setState(() {
        _messages.add(
          BlockChatMessage(
            role: BlockChatRole.assistant,
            text: value.substring(infoPrefix.length),
            createdAt: DateTime.now(),
          ),
        );
      });
      _scrollToEnd();
      return;
    }
    _send(value);
  }

  void _answerSuggestion(BlockChatSuggestion suggestion) {
    final answer = suggestion.answer;
    if (answer == null || answer.isEmpty) return;
    setState(() {
      _messages.add(
        BlockChatMessage(
          role: BlockChatRole.assistant,
          text: answer,
          createdAt: DateTime.now(),
        ),
      );
    });
    _scrollToEnd();
  }

  Future<void> _copyRecent24h() async {
    final entries = BlockAuditLogStore.loadWithin(const Duration(hours: 24));
    final text = BlockAuditLogStore.buildCopyText(entries, title: '최근 24시간 변경 로그');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          entries.isEmpty
              ? '최근 24시간 내 변경 없음 (빈 로그 복사됨)'
              : '최근 24시간 변경 ${entries.length}건 복사됨 — AI에 붙여넣기 하세요',
        ),
      ),
    );
  }

  Future<void> _copyFullTranscript() async {
    final text =
        BlockChatTranscriptService.buildFullTranscriptForCursor(_messages);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final turns = _messages.where((m) => !m.isLoading).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('대화 전부 복사됨 ($turns개) — Cursor·Claude에 붙여넣기'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: IsleColors.sand100,
      appBar: IsleAppBar(
        title: '차단 AI 챗',
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: '최근 24시간 변경만 복사 (디버그용)',
            onPressed: _copyRecent24h,
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: '받은 명령·적용 로그 (7일)',
            onPressed: () => context.push('/block/audit-log'),
          ),
        ],
      ),
      body: Column(
        children: [
          Builder(
            key: ValueKey(_configTick),
            builder: (_) {
              final configured = AiConfigStore.isConfigured;
              if (!configured || !_showAiStatus) return const SizedBox.shrink();
              return _CompactAiStatusBar(
                label: 'AI 연결됨 · ${AiConfigStore.activeProvider.displayName}',
                onOpenAiCenter: () async {
                  await context.push('/settings/ai-hub');
                  if (mounted) setState(() => _configTick++);
                },
                onClose: () => setState(() => _showAiStatus = false),
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
                final msg = _messages[i];
                return _Bubble(
                  message: msg,
                  onTryCoachPrompt: _busy ? null : _send,
                  onSuggestionTap: _busy ? null : _answerSuggestion,
                  onQuickReply: _busy ? null : _handleQuickReply,
                  onConfirm: msg.awaitingConfirm && !_busy
                      ? () => _confirmPlan(msg)
                      : null,
                  onCancel: msg.awaitingConfirm && !_busy
                      ? () => _cancelPlan(msg)
                      : null,
                );
              },
            ),
          ),
          Material(
            color: IsleColors.gold500.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SizedBox(
                width: double.infinity,
                height: IsleSize.minTouchTarget,
                child: OutlinedButton.icon(
                  onPressed: _messages.any((m) => !m.isLoading)
                      ? _copyFullTranscript
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: IsleColors.ocean900,
                    side: BorderSide(
                        color: IsleColors.gold500.withValues(alpha: 0.8)),
                  ),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('현재 대화 전체 복사'),
                ),
              ),
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
    final personas = BlockChatPersonaScenarios.all.take(4).toList();
    final commands = BlockChatDailyScenarios.all.take(5).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '추천 예시',
                  style: IsleText.caption(color: IsleColors.ocean700),
                ),
              ),
              TextButton.icon(
                onPressed: busy ? null : () => _showExamplesSheet(context),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: IsleColors.ocean700,
                ),
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('더보기'),
              ),
            ],
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: personas.length + commands.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index < personas.length) {
                  final p = personas[index];
                  return _CompactExampleChip(
                    label: p.persona,
                    icon: Icons.person_outline,
                    onTap: busy ? null : () => onTap(p.concern),
                  );
                }
                final s = commands[index - personas.length];
                return _CompactExampleChip(
                  label: s.title,
                  icon: Icons.bolt_outlined,
                  onTap: busy ? null : () => onTap(s.examplePrompt),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExamplesSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(
                  '상황을 고르면 채팅창에 바로 적용해요',
                  style: IsleText.subtitle(color: IsleColors.ocean900),
                ),
                const SizedBox(height: 12),
                Text('고민형',
                    style: IsleText.caption(color: IsleColors.ocean700)),
                const SizedBox(height: 8),
                for (final p in BlockChatPersonaScenarios.all)
                  _ExampleSheetTile(
                    title: p.persona,
                    subtitle: p.concern,
                    icon: Icons.person_outline,
                    onTap: () {
                      Navigator.of(context).pop();
                      onTap(p.concern);
                    },
                  ),
                const SizedBox(height: 14),
                Text('명령형',
                    style: IsleText.caption(color: IsleColors.ocean700)),
                const SizedBox(height: 8),
                for (final s in BlockChatDailyScenarios.all)
                  _ExampleSheetTile(
                    title: s.title,
                    subtitle: s.examplePrompt,
                    icon: Icons.bolt_outlined,
                    onTap: () {
                      Navigator.of(context).pop();
                      onTap(s.examplePrompt);
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CompactAiStatusBar extends StatelessWidget {
  const _CompactAiStatusBar({
    required this.label,
    required this.onOpenAiCenter,
    required this.onClose,
  });

  final String label;
  final VoidCallback onOpenAiCenter;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE8F5E9),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          child: Row(
            children: [
              const Icon(Icons.check_circle,
                  size: 16, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IsleText.caption(color: const Color(0xFF1B5E20)),
                ),
              ),
              TextButton(
                onPressed: onOpenAiCenter,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF1B5E20),
                ),
                child: const Text('AI 센터'),
              ),
              IconButton(
                tooltip: '닫기',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                color: const Color(0xFF1B5E20),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactExampleChip extends StatelessWidget {
  const _CompactExampleChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: IsleColors.ocean700),
      label: Text(label, style: IsleText.caption()),
      visualDensity: VisualDensity.compact,
      tooltip: label,
      onPressed: onTap,
    );
  }
}

class _ExampleSheetTile extends StatelessWidget {
  const _ExampleSheetTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: IsleColors.ocean100,
        child: Icon(icon, size: 18, color: IsleColors.ocean700),
      ),
      title: Text(title, style: IsleText.body(color: IsleColors.ocean900)),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: IsleText.caption(color: IsleColors.muted),
      ),
      onTap: onTap,
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    this.onTryCoachPrompt,
    this.onSuggestionTap,
    this.onQuickReply,
    this.onConfirm,
    this.onCancel,
  });

  final BlockChatMessage message;
  final void Function(String prompt)? onTryCoachPrompt;
  final void Function(BlockChatSuggestion suggestion)? onSuggestionTap;
  final void Function(String value)? onQuickReply;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

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
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isUser ? const Radius.circular(4) : null,
                bottomLeft: isUser ? null : const Radius.circular(4),
              ),
              border:
                  isError ? Border.all(color: const Color(0xFFEF9A9A)) : null,
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
          if (!isUser &&
              message.plan?.quickReplies?.isNotEmpty == true &&
              onQuickReply != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final opt in message.plan!.quickReplies!)
                    ActionChip(
                      label: Text(opt.label),
                      onPressed: () => onQuickReply!(opt.value),
                    ),
                ],
              ),
            ),
          if (message.awaitingConfirm && message.plan != null)
            _ConfirmCard(
              plan: message.plan!,
              onConfirm: onConfirm,
              onCancel: onCancel,
            ),
          if (message.result != null && !message.result!.isFailure) ...[
            if (message.result!.impact != null)
              BlockChatAppliedPanel(
                impact: message.result!.impact!,
                steps: message.result!.steps,
                permissionGaps: message.result!.permissionGaps,
              )
            else if (message.result!.steps.isNotEmpty)
              BlockChatSimpleAppliedList(
                steps: message.result!.steps,
                scheduledAuto: message.result!.removalScheduledAuto,
              ),
            if (message.result!.dailyTimeline != null &&
                message.result!.dailyTimeline!.isNotEmpty)
              BlockChatDailyTimelinePanel(
                items: message.result!.dailyTimeline!,
              ),
            if (message.result!.coach != null &&
                !message.result!.coach!.isEmpty)
              BlockChatCoachPanel(
                guide: message.result!.coach!,
                onTryChatPrompt: onTryCoachPrompt,
              ),
            if (message.result!.suggestions.isNotEmpty &&
                onSuggestionTap != null)
              BlockChatQuickReplyBar(
                suggestions: message.result!.suggestions,
                onTap: onSuggestionTap!,
              ),
          ],
        ],
      ),
    );
  }
}

/// 미리보기 → 확인/취소 — 적용 전 "이렇게 바꿀게요" 카드
class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({
    required this.plan,
    required this.onConfirm,
    required this.onCancel,
  });

  final BlockChatPlan plan;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final bullets = BlockChatPreview.bullets(plan);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.86,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: IsleColors.ocean100.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IsleColors.ocean500.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined,
                  size: 18, color: IsleColors.ocean700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '이렇게 바꿀게요',
                  style: IsleText.caption(color: IsleColors.ocean700)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final b in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: IsleText.body(color: IsleColors.ocean900)),
                    Expanded(
                      child: Text(
                        b,
                        style: IsleText.body(color: IsleColors.ocean900)
                            .copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (_DayTimelineBar.appliesTo(plan)) ...[
            const SizedBox(height: 6),
            _DayTimelineBar(plan: plan),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(IsleSize.minTouchTarget),
                    foregroundColor: IsleColors.muted,
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(IsleSize.minTouchTarget),
                    backgroundColor: IsleColors.ocean700,
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('확인 적용'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 확인 카드에 텍스트 요약("매일 0시~9시")만 있으면 그 구간이 하루 중
/// 실제로 얼마만큼인지, 자는 시간까지 걸치는 건 아닌지 한눈에 안 들어온다
/// — 24시간 축 위에 차단 구간을 막대로 시각화한다(2026-07-13, UI에 시간대
/// 프리뷰 요청). night_schedule/morning_schedule처럼 start~end 시각 구간이
/// 스케줄의 핵심인 액션에서만 보여준다.
class _DayTimelineBar extends StatelessWidget {
  const _DayTimelineBar({required this.plan});

  final BlockChatPlan plan;

  static bool appliesTo(BlockChatPlan plan) =>
      plan.action == 'night_schedule' || plan.action == 'morning_schedule';

  @override
  Widget build(BuildContext context) {
    const totalMin = 24 * 60;
    final startMin =
        ((plan.startHour ?? 0) * 60 + (plan.startMinute ?? 0)).clamp(0, 1439);
    final endMin = (plan.endHour * 60 + plan.endMinute).clamp(0, 1440);

    final segments = <(double, double)>[
      if (endMin > startMin)
        (startMin / totalMin, endMin / totalMin)
      else if (endMin < startMin) ...[
        // 자정을 넘기는 구간(예: 밤 23시~아침 7시) — 저녁 쪽과 새벽 쪽 두
        // 조각으로 나눠 표시해야 "자정에 풀렸다가 다시 걸린다"고 오해 안 함.
        (startMin / totalMin, 1.0),
        (0.0, endMin / totalMin),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: IsleColors.ocean100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  for (final seg in segments)
                    Positioned(
                      left: w * seg.$1,
                      width: (w * (seg.$2 - seg.$1)).clamp(2.0, w),
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: IsleColors.ocean700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0시', style: IsleText.caption(color: IsleColors.muted)),
            Text('12시', style: IsleText.caption(color: IsleColors.muted)),
            Text('24시', style: IsleText.caption(color: IsleColors.muted)),
          ],
        ),
      ],
    );
  }
}
