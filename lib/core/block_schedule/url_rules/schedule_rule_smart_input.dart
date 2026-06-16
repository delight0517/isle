import 'dart:math';

import '../../utils/url_parser.dart';
import '../../youtube/blocked_channel_store.dart';
import '../../youtube/content_filter_store.dart';
import '../../youtube/models/blocked_channel.dart';
import '../../youtube/models/blocked_video.dart';
import 'schedule_rule.dart';
import 'schedule_rule_kind.dart';
import 'schedule_rule_store.dart';
import 'url_rule_detector.dart';

class ScheduleRuleInsertResult {
  const ScheduleRuleInsertResult({
    required this.added,
    required this.duplicates,
    required this.skippedWholeSite,
    this.feedback,
  });

  final int added;
  final int duplicates;
  final int skippedWholeSite;
  final String? feedback;
}

/// detect → 저장 + 부가 store 연동 (Blueprint RuleSmartInput)
class ScheduleRuleSmartInput {
  ScheduleRuleSmartInput._();

  static Future<ScheduleRuleInsertResult> insert({
    required String scheduleId,
    required DetectedScheduleRule detected,
    required String rawInput,
    bool skipWholeSiteConfirm = false,
  }) async {
    if (detected.pattern.isEmpty) {
      return const ScheduleRuleInsertResult(added: 0, duplicates: 0, skippedWholeSite: 0);
    }

    if (!skipWholeSiteConfirm && UrlRuleDetector.needsWholeSiteConfirmation(detected)) {
      return const ScheduleRuleInsertResult(
        added: 0,
        duplicates: 0,
        skippedWholeSite: 1,
        feedback: 'YouTube 전체 차단은 확인 후 추가해 주세요',
      );
    }

    var added = 0;
    var dup = 0;

    Future<void> addOne(ScheduleRuleKind kind, String pattern, {String? raw}) async {
      if (ScheduleRuleStore.hasDuplicate(scheduleId: scheduleId, kind: kind, pattern: pattern)) {
        dup++;
        return;
      }
      final rule = ScheduleRule(
        id: _newId(),
        scheduleId: scheduleId,
        kind: kind,
        pattern: pattern.toLowerCase().trim(),
        rawInput: raw ?? rawInput,
        addedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await ScheduleRuleStore.upsert(rule);
      added++;
      await _applySideEffect(kind, pattern);
    }

    await addOne(detected.kind, detected.pattern);

    if (detected.secondaryHost != null) {
      await addOne(ScheduleRuleKind.host, detected.secondaryHost!, raw: rawInput);
    }

    String? feedback;
    if (detected.secondaryHost != null) {
      feedback =
          '숫자 우회 패턴 인식: \'${detected.pattern}\'+숫자 변형까지 막고, 지금 주소는 DNS에도 추가했어요.';
    } else if (detected.hint != null && added > 0) {
      feedback = detected.hint;
    }

    return ScheduleRuleInsertResult(
      added: added,
      duplicates: dup,
      skippedWholeSite: 0,
      feedback: feedback,
    );
  }

  static Future<ScheduleRuleInsertResult> addBulkSmart({
    required String scheduleId,
    required String text,
  }) async {
    var added = 0;
    var dup = 0;
    var skippedWhole = 0;

    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final detected = UrlRuleDetector.detect(trimmed);
      if (UrlRuleDetector.needsWholeSiteConfirmation(detected)) {
        skippedWhole++;
        continue;
      }
      final r = await insert(
        scheduleId: scheduleId,
        detected: detected,
        rawInput: trimmed,
        skipWholeSiteConfirm: true,
      );
      added += r.added;
      dup += r.duplicates;
    }

    final parts = <String>[];
    if (added > 0) parts.add('추가 $added개');
    if (dup > 0) parts.add('중복 $dup개');
    if (skippedWhole > 0) {
      parts.add('youtube 전체 $skippedWhole개는 개별 추가 시 확인 필요');
    }

    return ScheduleRuleInsertResult(
      added: added,
      duplicates: dup,
      skippedWholeSite: skippedWhole,
      feedback: parts.isEmpty ? null : parts.join(' · '),
    );
  }

  static Future<ScheduleRuleInsertResult> addUrlContains({
    required String scheduleId,
    required String stem,
  }) async {
    return insert(
      scheduleId: scheduleId,
      detected: DetectedScheduleRule(
        kind: ScheduleRuleKind.urlContains,
        pattern: stem.toLowerCase(),
        hint: '주소에 \'$stem\' 가 들어가면 모두 막습니다',
      ),
      rawInput: '포함:$stem',
    );
  }

  static Future<void> _applySideEffect(ScheduleRuleKind kind, String pattern) async {
    switch (kind) {
      case ScheduleRuleKind.keyword:
      case ScheduleRuleKind.genreKeyword:
        final kws = ContentFilterStore.loadKeywords();
        if (!kws.contains(pattern)) {
          await ContentFilterStore.saveKeywords([...kws, pattern]);
        }
      case ScheduleRuleKind.channelUrl:
        await BlockedChannelStore.ensureOpen();
        final list = BlockedChannelStore.loadAll();
        final id = pattern.startsWith('@') ? pattern : pattern;
        if (!list.any((c) => c.channelId == id || c.channelId == pattern)) {
          await BlockedChannelStore.saveAll([
            ...list,
            BlockedChannel(
              channelId: id,
              channelName: pattern,
              blockedAt: DateTime.now(),
            ),
          ]);
        }
      case ScheduleRuleKind.videoUrl:
        final vid = UrlParser.extractYouTubeVideoId(pattern) ??
            RegExp(r'([a-zA-Z0-9_-]{11})').firstMatch(pattern)?.group(1);
        if (vid != null) {
          final vids = ContentFilterStore.loadVideos();
          if (!vids.any((v) => v.videoId == vid)) {
            await ContentFilterStore.saveVideos([
              ...vids,
              BlockedVideo(videoId: vid, blockedAt: DateTime.now(), sourceUrl: pattern),
            ]);
          }
        }
      default:
        break;
    }
  }

  static String _newId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
}
