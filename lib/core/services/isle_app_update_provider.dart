import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/wdm_app_updater.dart';
import 'isle_app_log_service.dart';
import 'isle_app_update_config.dart';

final wdmAppUpdaterProvider = ChangeNotifierProvider<WdmAppUpdater>((ref) {
  return WdmAppUpdater(
    appId: IsleAppUpdateConfig.appId,
    catalogBaseUrl: IsleAppUpdateConfig.catalogBaseUrl,
  );
});

/// 설정 「업데이트 확인」·수동 점검
Future<void> runIsleAppUpdateCheck(
  BuildContext context,
  WidgetRef ref, {
  required bool manual,
}) async {
  final updater = ref.read(wdmAppUpdaterProvider);
  final found = await updater.checkNow(force: manual);
  if (!context.mounted) return;

  if (updater.error != null) {
    IsleAppLogService.log(
      'app update check failed: ${updater.error}',
      level: IsleLogLevel.warn,
    );
    if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업데이트 확인 실패: ${updater.error}')),
      );
    }
    return;
  }

  if (found) {
    await updater.showUpdateDialog(context);
    return;
  }

  if (manual) {
    final local = updater.local;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '최신 버전입니다 (${local?.version ?? ''}+${local?.buildNumber ?? ''})',
        ),
      ),
    );
  }
}
