import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/isle_app_log_service.dart';
import 'block_schedule_store.dart';
import 'models/block_schedule.dart';
import 'schedule_active_service.dart';
import 'schedule_enforcement_policy.dart';
import 'url_rules/host_expansion.dart';
import 'schedule_import_guard.dart';
import 'schedule_lock_service.dart';

/// Mac `/etc/hosts` + iPhone↔Mac JSON 동기화 (블루프린트 §5–6)
class BlockSyncExportService {
  BlockSyncExportService._();

  static const syncSchema = 1;

  static Map<String, dynamic> buildSyncPayload() {
    return {
      'sync_schema': syncSchema,
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'isle',
      'platform': Platform.operatingSystem,
      'block_schedules': BlockScheduleStore.loadAll().map((e) => e.toJson()).toList(),
      'active_schedule_ids': ScheduleActiveService.activeScheduleIdsNow(),
      'shield_schedule_ids': ScheduleEnforcementPolicy.shieldSchedulesNow().map((e) => e.id).toList(),
      'merged_domains': ScheduleEnforcementPolicy.mergedDomainsForShieldNow(),
    };
  }

  static String hostsFileSnippet({List<String>? domains}) {
    final list = domains ?? _allExpandedDomainsFromSchedules();
    final buf = StringBuffer()
      ..writeln('# Isle block schedules — paste into /etc/hosts on Mac (admin)')
      ..writeln('# Generated ${DateTime.now().toIso8601String()}')
      ..writeln();
    for (final d in list) {
      final host = d.replaceAll('https://', '').replaceAll('http://', '').split('/').first;
      if (host.isEmpty) continue;
      buf.writeln('0.0.0.0 $host');
      buf.writeln(':: $host');
    }
    return buf.toString();
  }

  static List<String> _allExpandedDomainsFromSchedules() {
    final active = ScheduleEnforcementPolicy.mergedDomainsForShieldNow();
    if (active.isNotEmpty) return active;
    final set = <String>{};
    for (final s in BlockScheduleStore.loadAll()) {
      for (final d in s.domains) {
        set.addAll(HostExpansion.expandHost(d));
      }
    }
    return set.toList()..sort();
  }

  static Future<void> shareMacHostsFile() async {
    final text = hostsFileSnippet();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/isle_mac_hosts_${DateTime.now().millisecondsSinceEpoch}.txt');
    await file.writeAsString(text);
    await Share.shareXFiles([XFile(file.path)], subject: 'Isle Mac hosts 차단');
  }

  static Future<void> shareSyncJson() async {
    final json = const JsonEncoder.withIndent('  ').convert(buildSyncPayload());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/isle_block_sync_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], subject: 'Isle 차단 스케줄 동기화');
  }

  static Future<int> importSyncPayload(String raw) async {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['block_schedules'];
    if (list is! List) return 0;
    var count = 0;
    final merged = [...BlockScheduleStore.loadAll()];
    final protected = ScheduleImportGuard.countProtected(merged, [
      for (final item in list)
        if (item is Map)
          BlockSchedule.fromJson(Map<String, dynamic>.from(item)),
    ]);
    for (final item in list) {
      if (item is! Map) continue;
      final incoming = BlockSchedule.fromJson(Map<String, dynamic>.from(item));
      final idx = merged.indexWhere((e) => e.id == incoming.id);
      if (idx >= 0) {
        merged[idx] = ScheduleImportGuard.mergeIncoming(
          existing: merged[idx],
          incoming: incoming,
        );
      } else {
        merged.add(incoming);
      }
      count++;
    }
    await BlockScheduleStore.saveAll(merged);
    await ScheduleLockService.finalizeExpiredLocks();
    if (protected > 0) {
      IsleAppLogService.log(
        'block sync import: $protected locked schedule(s) protected from override',
      );
    }
    return count;
  }
}
