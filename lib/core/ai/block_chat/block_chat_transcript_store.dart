import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../constants/app_release_info.dart';
import 'block_chat_models.dart';
import 'block_chat_transcript_service.dart';

/// 차단 AI 챗 — 실제 대화 원문(사용자 발화 + AI 응답 전문)을 7일간 저장.
///
/// `BlockAuditLogStore`(14일)와는 목적이 다르다 — 그쪽은 "무엇이 바뀌었는지"
/// 구조화된 요약(action/summary/steps)만 담고, 이 store는 확인 카드 문구·
/// 최종 응답 텍스트까지 포함한 **원문**을 담아서, 나중에 AI가 "그 채팅이
/// 정확히 어떻게 파싱되고 어떤 문구로 안내됐는지"까지 그대로 재구성해 볼 수
/// 있게 한다(2026-07-20 사용자 요청 — 채팅 시뮬레이터의 디버깅 로그 용도).
class BlockChatTranscriptEntry {
  const BlockChatTranscriptEntry({
    required this.id,
    required this.at,
    required this.appVersion,
    required this.userText,
    required this.assistantText,
    required this.planAction,
    required this.planJson,
    required this.outcome,
    required this.source,
  });

  final String id;
  final DateTime at;
  final String appVersion;
  final String userText;
  final String assistantText;
  final String? planAction;
  final Map<String, dynamic>? planJson;

  /// applied · cancelled · info_only · failed
  final String outcome;

  /// live(실제 앱 채팅) · simulator(디버깅 시뮬레이터)
  final String source;

  factory BlockChatTranscriptEntry.fromJson(Map<String, dynamic> j) =>
      BlockChatTranscriptEntry(
        id: j['id'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        appVersion: j['appVersion'] as String? ?? '',
        userText: j['userText'] as String? ?? '',
        assistantText: j['assistantText'] as String? ?? '',
        planAction: j['planAction'] as String?,
        planJson: (j['planJson'] as Map?)?.cast<String, dynamic>(),
        outcome: j['outcome'] as String? ?? 'applied',
        source: j['source'] as String? ?? 'live',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'appVersion': appVersion,
        'userText': userText,
        'assistantText': assistantText,
        if (planAction != null) 'planAction': planAction,
        if (planJson != null) 'planJson': planJson,
        'outcome': outcome,
        'source': source,
      };
}

class BlockChatTranscriptStore {
  BlockChatTranscriptStore._();

  static const _boxName = 'isle_block_chat_transcript';
  static const _key = 'entries_v1';
  static const retention = Duration(days: 7);

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('BlockChatTranscriptStore.ensureOpen() first');
    }
    return b;
  }

  static Future<void> recordTurn({
    required String userText,
    required String assistantText,
    BlockChatPlan? plan,
    required String outcome,
    String source = 'live',
  }) async {
    final list = _loadAllUnpruned();
    list.insert(
      0,
      BlockChatTranscriptEntry(
        id: 'turn_${DateTime.now().microsecondsSinceEpoch}',
        at: DateTime.now(),
        appVersion: AppReleaseInfo.pubspecVersion,
        userText: userText,
        assistantText: assistantText,
        planAction: plan?.action,
        planJson: plan == null ? null : BlockChatTranscriptService.planToMap(plan),
        outcome: outcome,
        source: source,
      ),
    );
    await _save(_prune(list));
  }

  /// 최근 7일(retention) 이내 항목만
  static List<BlockChatTranscriptEntry> loadRecent() => _prune(_loadAllUnpruned());

  static List<BlockChatTranscriptEntry> _loadAllUnpruned() {
    final raw = box.get(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => BlockChatTranscriptEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<BlockChatTranscriptEntry> _prune(List<BlockChatTranscriptEntry> list) {
    final cutoff = DateTime.now().subtract(retention);
    return list.where((e) => e.at.isAfter(cutoff)).toList();
  }

  static Future<void> _save(List<BlockChatTranscriptEntry> list) async {
    await box.put(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<void> pruneNow() async => _save(_prune(_loadAllUnpruned()));

  static Future<void> clear() => box.delete(_key);
}
