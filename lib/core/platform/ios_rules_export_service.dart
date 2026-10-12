import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../block_schedule/block_schedule_store.dart';
import '../block_schedule/schedule_enforcement_policy.dart';
import '../block_schedule/url_rules/schedule_rule_enforcement.dart';
import '../block_schedule/url_rules/schedule_rule_kind.dart';
import '../block_schedule/url_rules/schedule_rule_store.dart';
import '../intervention/website_block_store.dart';
import '../safety/content_safety_guard.dart';
import '../services/isle_app_log_service.dart';
import '../platform/ios_web_content_rule_service.dart';
import '../safe_browser/web_content_rule_compiler.dart';
import '../youtube/blocked_channel_store.dart';
import '../youtube/content_filter_store.dart';
import '../youtube/models/blocked_channel.dart';
import '../youtube/youtube_channel_pattern_normalizer.dart';

/// Safari Web Extension용 `rules_v1.json` (L2) — 확장 타깃 연결 전에도 App Group에 기록.
class IosRulesExportService {
  IosRulesExportService._();

  static const _channel = MethodChannel('com.isle.app/screen_time');

  /// 동시 export 직렬화 체인.
  /// 채팅 apply·YouTube 디바운스 등 여러 호출이 겹치면, 6개 스토어를 반쯤 읽은
  /// 상태로 rules JSON을 서로 덮어써(last-write-wins) 규칙이 유실되던 문제를 방지.
  /// 각 export는 반드시 직전 export가 끝난 뒤에만 스토어를 읽고 기록한다.
  static Future<void> _exportChain = Future<void>.value();

  /// 직렬화된 공개 진입점. 본문(_exportLocked)은 항상 이전 export 완료 후 실행된다.
  static Future<void> exportNow() {
    final next = _exportChain.then((_) => _exportLocked());
    // 한 번의 실패가 이후 export 체인을 영구히 막지 않도록 격리.
    _exportChain = next.catchError((Object _) {});
    return next;
  }

  static Future<void> _exportLocked() async {
    try {
      final domains = <String>{};
      domains.addAll(ScheduleRuleEnforcement.mergedExpandedHostsNow());
      for (final s in BlockScheduleStore.loadAll()) {
        if (!s.enabled) continue;
        domains.addAll(s.domains.map((d) => d.toLowerCase().trim()));
      }
      // 항상-차단 도메인 (WebsiteBlockSection에서 사용자가 토글) 포함
      await WebsiteBlockStore.ensureOpen();
      domains.addAll(WebsiteBlockStore.loadDomains().map((d) => d.toLowerCase().trim()));
      domains.addAll(ContentSafetyGuard.exportBlockDomains());

      final keywords = {
        ...ContentFilterStore.loadKeywords(),
        if (ContentSafetyGuard.enabled) ...ContentSafetyGuard.builtInYoutubeKeywords,
      }.toList()
        ..sort();
      final urlParts = ScheduleRuleEnforcement.mergedUrlPartsNow();
      final scheduleKeywords = ScheduleRuleEnforcement.activeKeywordsNow();

      await BlockedChannelStore.ensureOpen();
      final globalChannels = BlockedChannelStore.loadAll();
      final scheduleChannels = _scheduleChannelRulesAsBlocked();
      final blockedYoutubeChannels = YoutubeChannelPatternNormalizer.normalizedForExtension([
        ...globalChannels,
        ...scheduleChannels,
      ]);
      final blockedVideos = ContentFilterStore.loadVideos().map((v) => v.videoId).where((id) => id.length == 11).toList()..sort();

      final payload = {
        'version': 2,
        'exportedAtMs': DateTime.now().millisecondsSinceEpoch,
        'hideYtChannelSentry': true,
        'domains': domains.where((d) => d.isNotEmpty).toList()..sort(),
        'keywords': {
          ...keywords,
          ...scheduleKeywords,
        }.toList()
          ..sort(),
        'urlParts': urlParts,
        'blockedYoutubeChannels': blockedYoutubeChannels,
        'blockedChannels': blockedYoutubeChannels,
        'blockedVideos': blockedVideos,
      };
      await _channel.invokeMethod<void>('writeRulesJson', {
        'json': jsonEncode(payload),
      });
      await _writeContentBlocker(domains.toList()..sort());
      unawaited(IosWebContentRuleService.compileAfterExport());
    } catch (e, st) {
      IsleAppLogService.log(
        'IosRulesExportService.exportNow failed: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
    }
  }

  /// Safari Content Blocker 확장용 — `content_blocker_v1.json` (App Group).
  static Future<void> _writeContentBlocker(List<String> domains) async {
    final stems = await WebContentRuleCompiler.collectAlwaysOnStems();
    if (domains.isEmpty && stems.isEmpty) return;
    final rules = [
      ...WebContentRuleCompiler.rulesFromDomains(domains),
      ...WebContentRuleCompiler.rulesFromStems(stems),
    ];
    try {
      await _channel.invokeMethod<void>('writeContentBlockerJson', {
        'json': jsonEncode(rules),
      });
    } catch (e, st) {
      IsleAppLogService.log(
        'IosRulesExportService content_blocker failed: $e',
        level: IsleLogLevel.warn,
        stack: st,
      );
    }
  }

  static List<BlockedChannel> _scheduleChannelRulesAsBlocked() {
    final shieldIds = ScheduleEnforcementPolicy.shieldSchedulesNow().map((s) => s.id).toSet();
    if (shieldIds.isEmpty) return const [];
    final out = <BlockedChannel>[];
    for (final r in ScheduleRuleStore.loadAll()) {
      if (!shieldIds.contains(r.scheduleId)) continue;
      if (r.kind != ScheduleRuleKind.channelUrl) continue;
      out.add(BlockedChannel(
        channelId: r.pattern,
        channelName: r.pattern,
        blockedAt: DateTime.fromMillisecondsSinceEpoch(r.addedAtMs),
      ));
    }
    return out;
  }
}
