import 'package:flutter/material.dart';

import '../../../core/ai/ai_config_store.dart';
import '../../../core/ai/ai_provider_catalog.dart';
import '../../../core/ai/ai_usage_log_store.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/isle_app_bar.dart';

class AiUsageLogScreen extends StatelessWidget {
  const AiUsageLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = AiUsageLogStore.loadAll();

    return Scaffold(
      appBar: const IsleAppBar(title: 'AI 사용 기록'),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IsleColors.ocean100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이번 달 요약', style: IsleText.subtitle()),
                const SizedBox(height: 8),
                Text('API 전송 성공: ${AiUsageLogStore.successCountThisMonth}회'),
                Text('추정 비용: \$${AiUsageLogStore.usdThisMonth.toStringAsFixed(4)}'),
                Text('토큰 합계: ${AiUsageLogStore.tokensThisMonth}'),
                Text(
                  '현재: ${AiConfigStore.activeProvider.displayName} / ${AiConfigStore.resolvedModelId}',
                  style: IsleText.caption(color: IsleColors.muted),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      '아직 기록 없음\nAI를 쓰면 여기에 표시됩니다',
                      textAlign: TextAlign.center,
                      style: IsleText.body(color: IsleColors.muted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: entries.length,
                    itemBuilder: (_, i) => _LogTile(entry: entries[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final AiUsageLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final provider = AiProviderCatalog.byId(entry.providerId);
    final statusColor = switch (entry.status) {
      'success' => IsleColors.success,
      'skipped' => IsleColors.muted,
      'error' => IsleColors.danger,
      _ => IsleColors.ocean500,
    };
    final transferIcon = entry.dataTransferred ? Icons.cloud_upload : Icons.phone_android;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(transferIcon, color: statusColor, size: 20),
        ),
        title: Text(entry.featureLabel, style: IsleText.body()),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatAt(entry.at)} · ${entry.status}',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            if (entry.dataTransferred)
              Text(
                '${provider?.displayName ?? entry.providerId} · ${entry.modelId}\n'
                '${entry.inputTokens}+${entry.outputTokens} tok · \$${entry.usd.toStringAsFixed(4)}',
                style: IsleText.caption(color: IsleColors.ocean700),
              )
            else
              Text(entry.detail, style: IsleText.caption(color: IsleColors.muted)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatAt(DateTime d) {
    final local = d.toLocal();
    return '${local.month}/${local.day} ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }
}
