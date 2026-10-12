import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/ai/block_chat/block_audit_log_store.dart';
import 'package:isle/core/block/rule_pending_removal_store.dart';
import 'package:isle/core/block/premade_block_pack_removal_service.dart';
import 'package:isle/core/block/rule_pending_removal_service.dart';
import 'package:isle/core/block/premade_block_pack_service.dart';
import 'package:isle/core/intervention/website_block_store.dart';
import 'package:isle/core/services/isle_user_defaults.dart';
import 'package:isle/core/youtube/blocked_channel_store.dart';
import 'package:isle/core/youtube/blocked_url_store.dart';
import 'package:isle/core/youtube/content_filter_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_premade_pack_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
    await ContentFilterStore.ensureOpen();
    await BlockedChannelStore.ensureOpen();
    await BlockedUrlStore.ensureOpen();
    await WebsiteBlockStore.ensureOpen();
    await RulePendingRemovalStore.ensureOpen();
    RulePendingRemovalService.registerHandlers(
      removeKeyword: (key) async {
        final list = ContentFilterStore.loadKeywords()
          ..removeWhere((k) => k == key);
        await ContentFilterStore.saveKeywords(list);
      },
      removeUrl: BlockedUrlStore.remove,
      removePremadePack: PremadeBlockPackRemovalService.executeScheduledRemoval,
    );
  });

  test('loadCatalog includes adult + illegal · gaming · gambling', () async {
    PremadeBlockPackService.invalidateCatalogCache();
    final packs = await PremadeBlockPackService.loadCatalog();
    expect(packs.length, 4);
    expect(packs.first.packId, PremadeBlockPackService.adultCombinedPackId);
    expect(packs.any((p) => p.packId == 'premade_gaming_400'), isTrue);
    expect(
        packs.any((p) => p.packId == 'premade_jusoland_illegal_sites'), isTrue);
    expect(packs.any((p) => p.packId == 'premade_gambling_200'), isTrue);
    expect(packs.any((p) => p.packId == 'premade_adult_youtube_200'), isFalse);

    final toggle = await PremadeBlockPackService.loadToggleCatalog();
    expect(toggle.length, 3);
    expect(
        toggle.any(
            (p) => p.packId == PremadeBlockPackService.adultCombinedPackId),
        isFalse);

    final adult = await PremadeBlockPackService.loadAdultPack();
    expect(adult, isNotNull);
    expect(adult!.packId, PremadeBlockPackService.adultCombinedPackId);
    expect(adult.entryCount, greaterThan(400));
    expect(adult.entries.any((e) => e.pattern == 'missvod5.com'), isTrue);
    expect(adult.entries.any((e) => e.pattern == 'bozayo.net'), isTrue);
    expect(adult.entries.any((e) => e.pattern == '@pornhub'), isTrue);
  });

  test('apply merged adult pack adds channel keyword and url', () async {
    await ContentFilterStore.saveKeywords([]);
    await BlockedChannelStore.saveAll([]);
    await BlockedUrlStore.saveAll([]);
    await WebsiteBlockStore.saveDomains([]);
    await IsleUserDefaults.setRuleRemovalLockEnabled(false);
    final result = await PremadeBlockPackService.applyPack(
      PremadeBlockPackService.adultCombinedPackId,
    );
    expect(result.channelsAdded, greaterThan(0));
    expect(result.domainsAdded, greaterThan(0));
    expect(BlockedChannelStore.loadAll().any((c) => c.channelId == '@pornhub'),
        isTrue);
    expect(ContentFilterStore.loadKeywords(), contains('pornhub'));
    expect(
      IsleUserDefaults.getPremadePackProvenanceRaw(
        PremadeBlockPackService.adultCombinedPackId,
      ),
      isNotEmpty,
    );
  });

  test(
      'applying a pack records an apply_premade_pack entry in the audit log '
      '(2026-07-20 — 프리셋 팩은 blockedChannelsProvider를 안 거쳐서 별도로 '
      '기록 안 하면 "왜 이 채널이 차단됐지" 진단할 때 안 보이던 문제)',
      () async {
    await ContentFilterStore.saveKeywords([]);
    await BlockedChannelStore.saveAll([]);
    await BlockedUrlStore.saveAll([]);
    await WebsiteBlockStore.saveDomains([]);
    await IsleUserDefaults.setRuleRemovalLockEnabled(false);
    await BlockAuditLogStore.ensureOpen();
    await BlockAuditLogStore.clear();

    await PremadeBlockPackService.applyPack(
      PremadeBlockPackService.adultCombinedPackId,
    );

    final entries = BlockAuditLogStore.loadRecent();
    final match = entries.where((e) => e.action == 'apply_premade_pack');
    expect(match.length, 1);
    expect(match.first.summary, contains('adult_combined'));
    expect(match.first.success, isTrue);
  });

  test('remove pack schedules when removal lock on', () async {
    await IsleUserDefaults.setRuleRemovalLockEnabled(true);
    await IsleUserDefaults.setRuleRemovalFreezeMinutes(30);
    await PremadeBlockPackService.applyPack(
        PremadeBlockPackService.adultCombinedPackId);

    final outcome = await PremadeBlockPackRemovalService.requestRemoval(
      PremadeBlockPackService.adultCombinedPackId,
    );
    expect(outcome.kind, RuleRemovalOutcomeKind.scheduled);
    expect(
      PremadeBlockPackRemovalService.pendingRemoval(
        PremadeBlockPackService.adultCombinedPackId,
      ),
      isNotNull,
    );
    expect(
      BlockedChannelStore.loadAll().any((c) => c.channelId == '@pornhub'),
      isTrue,
    );
  });

  test('remove pack always schedules timer (even when lock off)', () async {
    await IsleUserDefaults.setRuleRemovalLockEnabled(false);
    await RulePendingRemovalStore.saveAll([]);
    await PremadeBlockPackService.applyPack(
        PremadeBlockPackService.adultCombinedPackId);
    expect(BlockedChannelStore.loadAll().any((c) => c.channelId == '@pornhub'),
        isTrue);

    final outcome = await PremadeBlockPackRemovalService.requestRemoval(
      PremadeBlockPackService.adultCombinedPackId,
    );
    expect(outcome.kind, RuleRemovalOutcomeKind.scheduled);
    expect(
      BlockedChannelStore.loadAll().any((c) => c.channelId == '@pornhub'),
      isTrue,
    );

    await PremadeBlockPackRemovalService.executeScheduledRemoval(
      PremadeBlockPackService.adultCombinedPackId,
    );
    expect(BlockedChannelStore.loadAll().any((c) => c.channelId == '@pornhub'),
        isFalse);
  });

  test('apply illegal webtoon pack adds domains', () async {
    await ContentFilterStore.saveKeywords([]);
    await WebsiteBlockStore.saveDomains([]);
    await IsleUserDefaults.setRuleRemovalLockEnabled(false);

    final result = await PremadeBlockPackService.applyPack(
      'premade_jusoland_illegal_sites',
    );
    expect(result.domainsAdded, greaterThan(0));
    expect(
      WebsiteBlockStore.loadDomains().any((d) => d.contains('11toon144.com')),
      isTrue,
    );
    expect(
      IsleUserDefaults.getPremadeBlockPackAppliedVersion(
        'premade_jusoland_illegal_sites',
      ),
      isNotNull,
    );
  });

  test(
      'applying premade_gaming_400 stores raw channel IDs (UC...) as-is, '
      'not mangled into a fake "@uc..." handle (2026-07-16 실사용 제보: '
      '게임 프리셋 채널이 실제로 차단이 안 됨 — normalizeHandle이 채널ID를 '
      'handle로 착각해 @ 접두사+소문자화하면서 실제 매칭용 문자열과 영원히 '
      '어긋났던 버그)', () async {
    PremadeBlockPackService.invalidateCatalogCache();
    await BlockedChannelStore.saveAll(const []);
    await IsleUserDefaults.unmarkPremadeBlockPackApplied('premade_gaming_400');

    final result =
        await PremadeBlockPackService.applyPack('premade_gaming_400');
    expect(result.channelsAdded, greaterThan(0));

    final channels = BlockedChannelStore.loadAll();
    final scChannel = channels
        .where((c) => c.channelId == 'UC4P7F8qenDo1O_5NvgBb_cg')
        .toList();
    expect(scChannel, isNotEmpty,
        reason: '채널 ID가 원형 그대로(대소문자 보존, @ 없이) 저장돼야 실제 '
            'YoutubeChannelPatternNormalizer 매칭과 일치함');
    expect(
      channels.any((c) => c.channelId.toLowerCase().contains('uc4p7f8')),
      isTrue,
    );
    expect(
      channels.any((c) => c.channelId == '@uc4p7f8qendo1o_5nvgbb_cg'),
      isFalse,
      reason: '이 잘못된 형태로 저장되면 실제 채널과 절대 매칭이 안 됨',
    );
  });

  test('pack update available when bundled version newer', () async {
    final packs = await PremadeBlockPackService.loadCatalog();
    final illegal =
        packs.firstWhere((p) => p.packId == 'premade_jusoland_illegal_sites');
    await IsleUserDefaults.markPremadeBlockPackApplied(illegal.packId,
        version: '0.0.1');
    expect(PremadeBlockPackService.isPackUpdateAvailable(illegal), isTrue);
    await IsleUserDefaults.unmarkPremadeBlockPackApplied(illegal.packId);
  });
}
