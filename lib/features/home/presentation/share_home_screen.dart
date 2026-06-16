import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/focus/isle_product_focus.dart';
import '../../../core/insight/knowledge_visual_system.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import 'widgets/share_instagram_dm_section.dart';
import 'widgets/share_inbound_links_card.dart';
import 'widgets/share_knowledge_outbound_card.dart';

/// 홈 ③ — **받기·소통**: 들어온 링크·DM 답장 (SNS 플랫폼·「공유하기」 아님)
class ShareHomeScreen extends StatelessWidget {
  const ShareHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IsleColors.sand100,
      appBar: const IsleAppBar(title: '받기 · 소통'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const _IntentHero(),
          const SizedBox(height: 16),
          const _StepLabel(step: '1', title: '소통 — DM으로 답장'),
          const ShareInstagramDmSection(),
          const SizedBox(height: 8),
          const _StepLabel(step: '2', title: '받기 — 링크를 지식으로'),
          const ShareInboundLinksCard(),
          const SizedBox(height: 8),
          const _StepLabel(step: '3', title: '보내기 — 지식 명함'),
          const ShareKnowledgeOutboundCard(),
          if (!IsleProductFocus.enabled) ...[
            const SizedBox(height: 20),
            Text('소셜 (고급)', style: IsleText.subtitle(color: IsleColors.ocean900)),
            ListTile(
              title: const Text('공유 플레이리스트'),
              onTap: () => context.push('/home/share/playlists'),
            ),
          ],
          if (!IsleProductFocus.hideSecondaryUi) ...[
            const Divider(height: 28),
            OutlinedButton.icon(
              onPressed: () => context.push('/feed'),
              icon: const Icon(Icons.rss_feed),
              label: const Text('RSS·구독 피드 (고급)'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Isle 3탭 중 이 화면의 역할 — SNS가 아님
class _IntentHero extends StatelessWidget {
  const _IntentHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KnowledgeVisual.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KnowledgeVisual.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '여기는 SNS가 아니에요',
            style: KnowledgeVisual.editorialBody(
              color: KnowledgeVisual.ink,
              fontSize: 18,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Isle은 스크롤 피드 앱이 아니라, '
            '친구·카톡·DM으로 들어온 것을 내 지식으로 바꾸고 '
            '필요할 때만 답장하는 공간이에요.',
            style: KnowledgeVisual.editorialBody(color: KnowledgeVisual.caption),
          ),
          const SizedBox(height: 14),
          const _FlowRow(
            icon: Icons.call_received,
            label: '받기',
            detail: '공유 시트·URL·나중에 볼',
            isLast: false,
          ),
          const _FlowRow(
            icon: Icons.auto_awesome_outlined,
            label: '정리',
            detail: '자막·인사이트·지식 명함',
          ),
          const _FlowRow(
            icon: Icons.reply_outlined,
            label: '답장',
            detail: 'Instagram DM (선택)',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({
    required this.icon,
    required this.label,
    required this.detail,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: KnowledgeVisual.intelligentBlue),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: IsleText.body(),
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: detail,
                    style: IsleText.caption(color: IsleColors.muted),
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

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.step, required this.title});

  final String step;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: KnowledgeVisual.intelligentBlueSoft,
            child: Text(
              step,
              style: KnowledgeVisual.editorialCaption(color: KnowledgeVisual.intelligentBlue),
            ),
          ),
          const SizedBox(width: 8),
          Text(title, style: IsleText.subtitle(color: IsleColors.ocean900)),
        ],
      ),
    );
  }
}
