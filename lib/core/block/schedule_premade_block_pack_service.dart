import 'dart:async';
import 'dart:math';

import '../block_schedule/block_schedule_enforcement_service.dart';
import '../block_schedule/url_rules/schedule_rule.dart';
import '../block_schedule/url_rules/schedule_rule_kind.dart';
import '../block_schedule/url_rules/schedule_rule_store.dart';
import '../intervention/website_block_store.dart';
import '../perf/isle_heavy_work.dart';
import '../perf/isle_heavy_work_reporter.dart';
import '../platform/ios_rules_export_service.dart';
import '../services/isle_app_log_service.dart';
import '../youtube/block_keyword_policy.dart';
import 'models/premade_block_pack.dart';
import 'premade_block_pack_registry.dart';
import 'premade_block_pack_service.dart';
import 'schedule_premade_pack_link.dart';
import 'schedule_premade_pack_store.dart';

class SchedulePremadePackLinkResult {
  const SchedulePremadePackLinkResult({
    required this.packId,
    required this.rulesAdded,
    required this.skipped,
    required this.isResync,
  });

  final String packId;
  final int rulesAdded;
  final int skipped;
  final bool isResync;

  String summary(String displayName) {
    if (rulesAdded == 0 && skipped > 0) {
      return isResync
          ? '「$displayName」 — 신규 규칙 없음 (중복 $skipped)'
          : '「$displayName」 — 이미 이 스케줄에 있어요';
    }
    final sync = isResync ? '동기화' : '연결';
    final skip = skipped > 0 ? ' · 중복 $skipped' : '';
    return '「$displayName」 $sync — 규칙 $rulesAdded개 추가$skip';
  }
}

/// 스케줄 편집 화면 — 프리셋 팩 → [ScheduleRuleStore] (스케줄 활성 시에만 적용)
class SchedulePremadePackService {
  SchedulePremadePackService._();

  static String pendingRemovalKey(String scheduleId, String packId) {
    final resolved = _resolvedPackId(packId);
    return 'schedule:$scheduleId:pack:$resolved';
  }

  static String? parseScheduleIdFromPendingKey(String key) {
    final m = RegExp(r'^schedule:(.+):pack:.+$').firstMatch(key);
    return m?.group(1);
  }

  static String? parsePackIdFromPendingKey(String key) {
    final m = RegExp(r'^schedule:.+:pack:(.+)$').firstMatch(key);
    return m?.group(1);
  }

  static bool isSchedulePendingKey(String key) => key.startsWith('schedule:');

  static String _resolvedPackId(String packId) =>
      PremadeBlockPackService.isLegacyAdultPackId(packId)
          ? PremadeBlockPackService.adultCombinedPackId
          : packId;

  static bool isLinked({required String scheduleId, required String packId}) =>
      SchedulePremadePackStore.isLinked(
        scheduleId: scheduleId,
        packId: _resolvedPackId(packId),
      );

  static String? linkedVersion({required String scheduleId, required String packId}) =>
      SchedulePremadePackStore.findLink(
        scheduleId: scheduleId,
        packId: _resolvedPackId(packId),
      )?.version;

  static bool isUpdateAvailable({
    required String scheduleId,
    required PremadeBlockPack pack,
  }) {
    if (!isLinked(scheduleId: scheduleId, packId: pack.packId)) return false;
    final linked = linkedVersion(scheduleId: scheduleId, packId: pack.packId);
    if (linked == null || linked.isEmpty) return false;
    return pack.version.compareTo(linked) > 0;
  }

  static List<SchedulePremadePackLink> linksForSchedule(String scheduleId) =>
      SchedulePremadePackStore.linksForSchedule(scheduleId);

  static Future<SchedulePremadePackLinkResult> linkPack({
    required String scheduleId,
    required String packId,
  }) =>
      IsleHeavyWork.run(
        taskId: 'schedule_premade_pack',
        userTitle: '스케줄에 프리셋 연결 중',
        userWhy: '이 스케줄이 켜질 때만 적용되는 차단 규칙을 추가해요.',
        estimatedMs: 8000,
        work: (r) => _linkBody(scheduleId: scheduleId, packId: packId, reporter: r),
      );

  static Future<SchedulePremadePackLinkResult> _linkBody({
    required String scheduleId,
    required String packId,
    required IsleHeavyWorkReporter reporter,
  }) async {
    final resolvedId = _resolvedPackId(packId);
    if (PremadeBlockPackService.isAdultPackId(resolvedId)) {
      throw StateError(
        '성인 보호는 보호 필터에서만 설정해요 — 스케줄 프리셋과 분리했습니다',
      );
    }
    final def = PremadeBlockPackRegistry.definitionFor(resolvedId);
    if (def != null && !def.scheduleEligible) {
      throw StateError(
        '「${PremadeBlockPackRegistry.labelForPackId(resolvedId)}」는 보호 필터에서만 설정해요',
      );
    }
    final pack = await PremadeBlockPackService.packById(resolvedId);
    if (pack == null) {
      throw StateError('Unknown pack: $packId');
    }

    final wasLinked = isLinked(scheduleId: scheduleId, packId: resolvedId);
    final existing = ScheduleRuleStore.loadForSchedule(scheduleId);
    final dupKeys = {
      for (final r in existing) '${r.kind.storageKey}|${r.pattern}',
    };

    final toAdd = <ScheduleRule>[];
    var skipped = 0;
    final seenInPack = <String>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    final total = pack.entries.length;
    var processed = 0;

    for (final entry in pack.entries) {
      processed++;
      if (total > 20 && processed % 20 == 0) {
        reporter.progress(
          0.1 + (processed / total) * 0.8,
          stepLabel: '규칙 변환 $processed / $total',
        );
      }
      if (!seenInPack.add(entry.dedupeKey)) {
        skipped++;
        continue;
      }

      final mapped = _mapEntry(entry);
      if (mapped == null) {
        skipped++;
        continue;
      }

      final dupKey = '${mapped.kind.storageKey}|${mapped.pattern}';
      if (dupKeys.contains(dupKey)) {
        skipped++;
        continue;
      }

      dupKeys.add(dupKey);
      toAdd.add(
        ScheduleRule(
          id: _newId(),
          scheduleId: scheduleId,
          kind: mapped.kind,
          pattern: mapped.pattern,
          rawInput: '프리셋:${pack.displayName}',
          addedAtMs: now,
          premadePackId: resolvedId,
        ),
      );

      if (processed % 12 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    reporter.progress(0.92, stepLabel: '저장');
    if (toAdd.isNotEmpty) {
      final all = ScheduleRuleStore.loadAll()..addAll(toAdd);
      await ScheduleRuleStore.saveAll(all);
    }

    await SchedulePremadePackStore.upsert(
      SchedulePremadePackLink(
        scheduleId: scheduleId,
        packId: resolvedId,
        version: pack.version,
        linkedAtMs: now,
      ),
    );

    unawaited(_syncEnforcement());

    IsleAppLogService.log(
      'Schedule premade $resolvedId @$scheduleId: +${toAdd.length} skip$skipped resync=$wasLinked',
    );

    return SchedulePremadePackLinkResult(
      packId: resolvedId,
      rulesAdded: toAdd.length,
      skipped: skipped,
      isResync: wasLinked,
    );
  }

  static Future<void> unlinkImmediate({
    required String scheduleId,
    required String packId,
  }) async {
    final resolvedId = _resolvedPackId(packId);
    await ScheduleRuleStore.deleteForScheduleAndPack(
      scheduleId: scheduleId,
      packId: resolvedId,
    );
    await SchedulePremadePackStore.removeLink(
      scheduleId: scheduleId,
      packId: resolvedId,
    );
    await _syncEnforcement();
    IsleAppLogService.log('Schedule premade unlinked $resolvedId @$scheduleId');
  }

  static Future<void> deleteScheduleLinks(String scheduleId) async {
    await SchedulePremadePackStore.deleteLinksForSchedule(scheduleId);
  }

  static Future<void> _syncEnforcement() async {
    try {
      await BlockScheduleEnforcementService.syncPlatformEnforcement();
      await IosRulesExportService.exportNow();
    } catch (e, st) {
      IsleAppLogService.log(
        'Schedule premade enforcement sync skipped: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
    }
  }

  static _MappedEntry? _mapEntry(PremadeBlockPackEntry entry) {
    final raw = entry.pattern.trim();
    if (raw.isEmpty) return null;

    switch (entry.kind) {
      case 'channelURL':
        final handle = _normalizeHandle(raw);
        if (handle.isEmpty) return null;
        return _MappedEntry(ScheduleRuleKind.channelUrl, handle);
      case 'wildcard':
        return _MappedEntry(ScheduleRuleKind.wildcard, raw.toLowerCase());
      case 'keyword':
        final k = raw.toLowerCase();
        if (!BlockKeywordPolicy.isSafePremadeKeyword(k)) return null;
        return _MappedEntry(ScheduleRuleKind.keyword, k);
      case 'urlContains':
      case 'videoURL':
        final p = raw.toLowerCase();
        if (p.isEmpty) return null;
        return _MappedEntry(
          entry.kind == 'videoURL' ? ScheduleRuleKind.videoUrl : ScheduleRuleKind.urlContains,
          p.replaceFirst(RegExp(r'^https?://'), ''),
        );
      case 'host':
        if (raw.contains('/')) {
          final path = raw.startsWith('http') ? raw : 'https://$raw';
          final uri = Uri.tryParse(path);
          if (uri == null) return null;
          final stem = (uri.host + uri.path).toLowerCase();
          if (stem.isEmpty) return null;
          return _MappedEntry(ScheduleRuleKind.urlContains, stem);
        }
        final domain = WebsiteBlockStore.normalizeDomain(raw) ??
            raw.toLowerCase().split('/').first;
        if (domain.isEmpty || !BlockKeywordPolicy.isSafePremadeWebsiteDomain(domain)) {
          return null;
        }
        return _MappedEntry(ScheduleRuleKind.host, domain);
      default:
        return null;
    }
  }

  static String _normalizeHandle(String raw) {
    var h = raw.trim().toLowerCase();
    if (h.isEmpty) return '';
    if (!h.startsWith('@')) h = '@$h';
    return h;
  }

  static String _newId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
}

class _MappedEntry {
  const _MappedEntry(this.kind, this.pattern);
  final ScheduleRuleKind kind;
  final String pattern;
}
