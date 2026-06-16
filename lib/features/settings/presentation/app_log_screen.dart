import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_release_info.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/isle_app_log_service.dart';
import '../../../shared/widgets/copy_text_row.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../../shared/widgets/isle_developer_delay_report_card.dart';

class AppLogScreen extends StatefulWidget {
  const AppLogScreen({super.key});

  @override
  State<AppLogScreen> createState() => _AppLogScreenState();
}

class _AppLogScreenState extends State<AppLogScreen> {
  @override
  Widget build(BuildContext context) {
    final logs = IsleAppLogService.recent.reversed.toList();
    final allText = logs.map((e) => e.formatLine()).join('\n');

    return Scaffold(
      appBar: const IsleAppBar(title: '앱 로그'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: IsleDeveloperDelayReportCard(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CopyTextRow(label: '현재 버전', value: AppReleaseInfo.label),
          ),
          Expanded(
            child: logs.isEmpty
                ? Center(child: Text('아직 로그 없음', style: IsleText.body()))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: logs.length,
                    itemBuilder: (_, i) {
                      final e = logs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SelectableText(
                          e.formatLine(),
                          style: IsleText.caption().copyWith(fontFamily: 'monospace', fontSize: 12),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: allText.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: allText));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('전체 로그 복사됨')),
                        );
                      }
                    },
              icon: const Icon(Icons.copy_all),
              label: const Text('전체 로그 복사'),
            ),
          ),
        ],
      ),
    );
  }
}
