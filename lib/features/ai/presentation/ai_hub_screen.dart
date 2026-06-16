import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ai/api_key_setup_service.dart';
import '../../../core/ai/ai_activity_service.dart';
import '../../../core/ai/ai_client.dart';
import '../../../core/ai/ai_config_store.dart';
import '../../../core/ai/ai_provider_catalog.dart';
import '../../../core/ai/ai_usage_log_store.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../youtube/presentation/widgets/isle_youtube_schedule_sheet.dart';
import 'widgets/ai_honeycomb_worker.dart';
import 'widgets/ai_key_auto_setup_card.dart';
import 'widgets/ai_waiting_card.dart';

/// AI 제공자·모델·키·가이드라인·예산 — 단일 허브
class AiHubScreen extends StatefulWidget {
  const AiHubScreen({super.key});

  @override
  State<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends State<AiHubScreen> {
  late String _providerId;
  late String _modelId;
  late String _customModel;
  late String _baseUrl;
  late TextEditingController _keyCtrl;
  late TextEditingController _baseUrlCtrl;
  late TextEditingController _customModelCtrl;
  late double _budget;
  late bool _enforced;
  bool _obscureKey = true;
  bool _saving = false;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _providerId = AiConfigStore.providerId;
    _modelId = AiConfigStore.modelId;
    _customModel = AiConfigStore.customModelId;
    _baseUrl = AiConfigStore.baseUrlOverride ?? '';
    _keyCtrl = TextEditingController(
      text: AiConfigStore.isConfigured ? AiConfigStore.apiKeyMasked : '',
    );
    _baseUrlCtrl = TextEditingController(text: _baseUrl);
    _customModelCtrl = TextEditingController(text: _customModel);
    _budget = IsleUserDefaults.apiMonthlyBudgetUsd;
    _enforced = IsleUserDefaults.apiBudgetEnforced;
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _customModelCtrl.dispose();
    super.dispose();
  }

  AiProviderDefinition get _provider =>
      AiProviderCatalog.byId(_providerId) ?? AiProviderCatalog.providers.first;

  void _reloadFromStore() {
    setState(() {
      _providerId = AiConfigStore.providerId;
      _modelId = AiConfigStore.modelId;
      _customModel = AiConfigStore.customModelId;
      _baseUrl = AiConfigStore.baseUrlOverride ?? '';
      _keyCtrl.text = AiConfigStore.isConfigured ? AiConfigStore.apiKeyMasked : '';
      _baseUrlCtrl.text = _baseUrl;
      _customModelCtrl.text = _customModel;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final key = _keyCtrl.text.trim();
    final base = _baseUrlCtrl.text.trim();
    if (_enforced && _budget < 0.5) {
      _budget = 1.0;
    }
    await AiConfigStore.setProviderId(_providerId);
    await AiConfigStore.setModelId(_modelId);
    if (key.isEmpty) {
      await AiConfigStore.clearApiKey();
    } else if (!key.startsWith('****')) {
      await AiConfigStore.setApiKey(key);
    }
    await AiConfigStore.setBaseUrlOverride(base.isEmpty ? null : base);
    if (_providerId == 'custom') {
      await AiConfigStore.setCustomModelId(_customModelCtrl.text.trim());
    }
    await IsleUserDefaults.setApiMonthlyBudgetUsd(_budget);
    await IsleUserDefaults.setApiBudgetEnforced(_enforced);
    if (mounted) {
      setState(() {
        _saving = false;
        _testResult = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            key.isEmpty
                ? '저장됨 — API 키가 비어 있어 AI는 꺼진 상태예요'
                : 'AI 설정 저장됨 — 차단 AI 챗에서 바로 사용해요',
          ),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    if (!AiConfigStore.isConfigured && _keyCtrl.text.trim().isEmpty) {
      setState(() => _testResult = 'API 키를 입력한 뒤 「붙여넣고 연결」을 누르세요.');
      return;
    }
    if (_keyCtrl.text.trim().isNotEmpty && !_keyCtrl.text.startsWith('****')) {
      await ApiKeySetupService.applyFromPaste(_keyCtrl.text);
      _reloadFromStore();
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final r = await AiClient.chat(
      feature: 'ai_hub_test',
      systemPrompt: 'Reply with exactly: ok',
      userPrompt: 'ping',
      maxTokens: 8,
      temperature: 0,
    );
    if (!mounted) return;
    setState(() {
      _testing = false;
      if (r.usedAi) {
        _testResult = '연결 성공 — ${AiConfigStore.activeProvider.displayName}';
      } else if (r.error == 'budget') {
        _testResult = '예산이 0이에요. 슬라이더를 \$1 이상으로 올려 주세요.';
      } else {
        _testResult = r.error ?? '연결 실패 — 키·모델·Base URL 확인';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activities = AiActivityService.currentActivities();
    final configured = AiConfigStore.isConfigured;
    final hasWork = activities.any(
      (a) => a.kind == AiActivityKind.waiting || a.kind == AiActivityKind.processing,
    );

    return Scaffold(
      appBar: IsleAppBar(
        title: 'AI 센터',
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: '사용 기록',
            onPressed: () => context.push('/settings/ai-usage-log'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _WhyApiIllustration(),
          if (hasWork) ...[
            const SizedBox(height: 16),
            Center(
              child: AiHoneycombWorker(
                size: 120,
                active: true,
                showOutbound: activities.any((a) => a.kind == AiActivityKind.processing),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _StatusBanner(configured: configured),
          const SizedBox(height: 12),
          AiKeyAutoSetupCard(onApplied: _reloadFromStore),
          const SizedBox(height: 12),
          _ScheduleQuickLinks(onReload: _reloadFromStore),
          const SizedBox(height: 12),
          if (_enforced && _budget < 0.5)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '예산이 \$0이면 API 키가 있어도 AI가 막혀요. 슬라이더를 \$1 이상으로 올리거나 예산 차단을 끄세요.',
                style: IsleText.caption(color: const Color(0xFFB71C1C)),
              ),
            ),
          FilledButton.icon(
            onPressed: _saving || _testing ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('1. 설정 저장'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _testing ? null : _testConnection,
            icon: _testing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering),
            label: const Text('2. 연결 테스트'),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Text(_testResult!, style: IsleText.caption(color: IsleColors.ocean700)),
          ],
          const Divider(height: 28),
          const SizedBox(height: 4),
          Text('AI가 하는 일 (지금)', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          Text(
            '글자 설명만이 아니라, 대기·전송·완료 상태를 보여 드립니다.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 12),
          ...activities.map((a) => AiWaitingCard(item: a)),
          if (activities.isEmpty)
            Text('대기 중인 AI 작업 없음', style: IsleText.body(color: IsleColors.muted)),
          Card(
            color: const Color(0xFFE8F5E9),
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF2E7D32)),
              title: Text('차단 AI 챗', style: IsleText.subtitle()),
              subtitle: Text(
                '말로 스케줄·키워드·앱 한도 설정 — 적용 후 설정 화면으로 이동',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/block-chat'),
            ),
          ),
          const Divider(height: 32),
          Text('어떤 AI를 쓸까요?', style: IsleText.subtitle()),
          const SizedBox(height: 8),
          ...AiProviderCatalog.providers.map((p) {
            final selected = p.id == _providerId;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: selected ? IsleColors.ocean100 : null,
              child: ListTile(
                title: Text(p.displayName),
                subtitle: Text(
                  p.hint ?? '${p.models.length}개 모델 · ${_apiStyleLabel(p.apiStyle)}',
                  style: IsleText.caption(color: IsleColors.muted),
                ),
                trailing: selected ? const Icon(Icons.check_circle, color: IsleColors.ocean500) : null,
                onTap: () => setState(() {
                  _providerId = p.id;
                  _modelId = p.models.first.id;
                }),
              ),
            );
          }),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _modelId,
            decoration: const InputDecoration(
              labelText: '모델 버전',
              border: OutlineInputBorder(),
            ),
            items: _provider.models
                .map((m) => DropdownMenuItem(value: m.id, child: Text(m.label)))
                .toList(),
            onChanged: (v) => setState(() => _modelId = v ?? _modelId),
          ),
          if (_providerId == 'custom') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customModelCtrl,
              decoration: const InputDecoration(
                labelText: '사용자 지정 모델 ID',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _customModel = v,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _keyCtrl,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'API 키 (고급 — 직접 입력)',
              hintText: AiConfigStore.isConfigured
                  ? '연결됨 · ${AiConfigStore.apiKeyMasked}'
                  : '위 「붙여넣고 연결」 권장',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
            onChanged: (v) {
              if (v.startsWith('****')) return;
            },
          ),
          if (_provider.docsUrl != null)
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(_provider.docsUrl!)),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('키 발급 페이지'),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _baseUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'Base URL (선택, 덮어쓰기)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _baseUrl = v,
          ),
          const Divider(height: 28),
          _GuidelinesSection(),
          const Divider(height: 28),
          Text('월 예산 (USD)', style: IsleText.subtitle()),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('예산 초과 시 AI 차단'),
            value: _enforced,
            onChanged: (v) => setState(() => _enforced = v),
          ),
          Slider(
            min: 0,
            max: 50,
            divisions: 50,
            value: _budget,
            label: '\$${_budget.toStringAsFixed(1)}',
            onChanged: (v) => setState(() => _budget = v),
          ),
          Text(
            '이번 달 AI: \$${AiUsageLogStore.usdThisMonth.toStringAsFixed(3)} · '
            '${AiUsageLogStore.tokensThisMonth} tokens · '
            '${AiUsageLogStore.successCountThisMonth}회 전송',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _apiStyleLabel(AiApiStyle s) => switch (s) {
        AiApiStyle.openAiChat => 'OpenAI 호환',
        AiApiStyle.anthropicMessages => 'Claude API',
        AiApiStyle.geminiGenerate => 'Gemini API',
      };
}

/// 시각적 안내 — API가 왜 필요한지
class _WhyApiIllustration extends StatelessWidget {
  const _WhyApiIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IsleColors.ocean100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IsleColors.ocean100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('왜 API 키가 필요할까요?', style: IsleText.subtitle(color: IsleColors.ocean900)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _illusStep(Icons.phone_iphone, 'Isle', '저장·관심·차단'),
              Padding(
                padding: const EdgeInsets.only(top: 18, left: 4, right: 4),
                child: Icon(Icons.arrow_forward, color: IsleColors.ocean500.withValues(alpha: 0.6)),
              ),
              _illusStep(Icons.key, 'API 키', '이 기기만'),
              Padding(
                padding: const EdgeInsets.only(top: 18, left: 4, right: 4),
                child: Icon(Icons.arrow_forward, color: IsleColors.ocean500.withValues(alpha: 0.6)),
              ),
              _illusStep(Icons.cloud_outlined, 'AI', '요약·기사'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Isle는 기본적으로 로컬에서 동작합니다. 아래 키를 저장하면 선택한 제공자로만 '
            '요약·「관심→기사」·채널 장르 분석 요청이 나갑니다. 키 없이도 피드·섬·차단은 사용할 수 있어요.',
            style: IsleText.caption(color: IsleColors.ocean700),
          ),
        ],
      ),
    );
  }

  Widget _illusStep(IconData icon, String title, String sub) => Expanded(
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: IsleColors.ocean100,
              child: Icon(icon, color: IsleColors.ocean700, size: 22),
            ),
            const SizedBox(height: 6),
            Text(title, style: IsleText.caption(), textAlign: TextAlign.center),
            Text(sub, style: IsleText.caption(color: IsleColors.muted), textAlign: TextAlign.center),
          ],
        ),
      );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.configured});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: configured
              ? [IsleColors.ocean900, IsleColors.ocean500]
              : [IsleColors.muted, IsleColors.muted.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                configured ? Icons.cloud_done : Icons.cloud_off,
                color: configured ? IsleColors.gold500 : Colors.white70,
              ),
              const SizedBox(width: 10),
              Text(
                configured ? 'AI 연결 가능' : 'AI 꺼짐 — 로컬만',
                style: IsleText.subtitle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            configured
                ? '${AiConfigStore.activeProvider.displayName} · ${AiConfigStore.resolvedModelId}\n'
                    '키: ${AiConfigStore.apiKeyMasked}\n'
                    '네트워크 전송은 요약·기사화·유형분석 시에만 발생합니다.'
                : 'API 키를 넣기 전까지 데이터는 외부로 나가지 않습니다.',
            style: IsleText.caption(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _GuidelinesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AI 사용 가이드', style: IsleText.subtitle()),
        const SizedBox(height: 10),
        _GuideRow(
          icon: Icons.favorite_border,
          title: '관심 → 기사',
          body: '피드 스와이프 후 ${IsleUserDefaults.interestArticleDays}일 대기 → 그때 API 호출',
        ),
        _GuideRow(
          icon: Icons.auto_stories_outlined,
          title: '요약 카드',
          body: '내 콘텐츠·다이제스트 — 주 ${IsleUserDefaults.digestMaxPerWeek}회 한도',
        ),
        _GuideRow(
          icon: Icons.category_outlined,
          title: '유형 차단',
          body: '분석 버튼을 눌렀을 때만 채널 샘플 전송',
        ),
        _GuideRow(
          icon: Icons.playlist_play,
          title: '나중에 볼 추천',
          body: '가져오기 실행 시에만 (선택)',
        ),
        const SizedBox(height: 8),
        Text(
          '모든 호출은 「AI 사용 기록」에 남습니다. 전송 없음(skipped)도 기록됩니다.',
          style: IsleText.caption(color: IsleColors.ocean700),
        ),
      ],
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: IsleColors.ocean500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: IsleText.body()),
                Text(body, style: IsleText.caption(color: IsleColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// AI 센터 — 스케줄·차단 챗 바로가기
class _ScheduleQuickLinks extends StatelessWidget {
  const _ScheduleQuickLinks({required this.onReload});

  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IsleSize.cardRadius),
        side: BorderSide(color: IsleColors.ocean100),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.schedule, color: IsleColors.ocean700),
            title: Text('Isle 유튜브 스케줄', style: IsleText.body()),
            subtitle: Text(
              '매일 아침까지 앱 안 유튜브 차단 · AI 챗과 동일',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showIsleYoutubeScheduleSheet(context),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF2E7D32)),
            title: Text('차단 AI 챗', style: IsleText.body()),
            subtitle: Text(
              '「매일 10시까지 isle 유튜브 차단」처럼 말로 설정',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await context.push('/settings/block-chat');
              onReload();
            },
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.event_repeat, color: IsleColors.ocean700),
            title: Text('차단 스케줄 목록', style: IsleText.body()),
            subtitle: Text(
              '요일·시간·Isle/Safari 대상 편집',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/block-schedules'),
          ),
        ],
      ),
    );
  }
}
