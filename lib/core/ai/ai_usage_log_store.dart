import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// AI 호출 기록 — 사용자가 설정에서 투명하게 확인
class AiUsageLogEntry {
  const AiUsageLogEntry({
    required this.id,
    required this.at,
    required this.feature,
    required this.providerId,
    required this.modelId,
    required this.status,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.usd = 0,
    this.detail = '',
    this.dataTransferred = false,
    this.systemPrompt = '',
    this.userPrompt = '',
    this.rawResponse = '',
    this.parseError = '',
  });

  final String id;
  final DateTime at;
  final String feature;
  final String providerId;
  final String modelId;
  final String status; // success | fallback | skipped | error
  final int inputTokens;
  final int outputTokens;
  final double usd;
  final String detail;
  final bool dataTransferred;
  /// AI에게 실제로 보낸 요청 원문 — "AI가 왜 이렇게 답했는지" 디버깅용
  /// (2026-[REDACTED] 사용자 요청). 길이 제한은 [AiClient._truncateForLog] 참고.
  final String systemPrompt;
  final String userPrompt;
  /// AI가 실제로 준 응답 원문(파싱 전) — 성공/실패 모두 기록.
  final String rawResponse;
  /// 응답은 왔지만 앱이 그걸 계획(JSON)으로 못 바꿨을 때의 사유 — 호출
  /// 시점엔 아직 모르므로 [AiUsageLogStore.attachParseError]로 사후에 채워진다.
  final String parseError;

  factory AiUsageLogEntry.fromJson(Map<String, dynamic> j) => AiUsageLogEntry(
        id: j['id'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        feature: j['feature'] as String? ?? '',
        providerId: j['provider_id'] as String? ?? '',
        modelId: j['model_id'] as String? ?? '',
        status: j['status'] as String? ?? 'unknown',
        inputTokens: (j['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (j['output_tokens'] as num?)?.toInt() ?? 0,
        usd: (j['usd'] as num?)?.toDouble() ?? 0,
        detail: j['detail'] as String? ?? '',
        dataTransferred: j['data_transferred'] == true,
        systemPrompt: j['system_prompt'] as String? ?? '',
        userPrompt: j['user_prompt'] as String? ?? '',
        rawResponse: j['raw_response'] as String? ?? '',
        parseError: j['parse_error'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'feature': feature,
        'provider_id': providerId,
        'model_id': modelId,
        'status': status,
        'input_tokens': inputTokens,
        'output_tokens': outputTokens,
        'usd': usd,
        'detail': detail,
        'data_transferred': dataTransferred,
        if (systemPrompt.isNotEmpty) 'system_prompt': systemPrompt,
        if (userPrompt.isNotEmpty) 'user_prompt': userPrompt,
        if (rawResponse.isNotEmpty) 'raw_response': rawResponse,
        if (parseError.isNotEmpty) 'parse_error': parseError,
      };

  AiUsageLogEntry copyWith({String? parseError}) => AiUsageLogEntry(
        id: id,
        at: at,
        feature: feature,
        providerId: providerId,
        modelId: modelId,
        status: status,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        usd: usd,
        detail: detail,
        dataTransferred: dataTransferred,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        rawResponse: rawResponse,
        parseError: parseError ?? this.parseError,
      );

  String get featureLabel => AiUsageLogStore.featureLabels[feature] ?? feature;
}

class AiUsageLogStore {
  AiUsageLogStore._();

  static const _boxName = 'isle_ai_usage_log';
  static const _logKey = 'entries_v2';
  static const maxEntries = 200;

  static const featureLabels = <String, String>{
    'summarize': '요약 카드',
    'interest_article': '관심 → 기사',
    'genre_block': '유형 차단 분석',
    'watch_later_curate': '나중에 볼 추천',
    'digest': '요약 뉴스',
    'block_chat': '차단 AI 챗',
  };

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('AiUsageLogStore not open');
    return b;
  }

  static Future<void> append(AiUsageLogEntry entry) async {
    final list = loadAll();
    list.insert(0, entry);
    if (list.length > maxEntries) list.length = maxEntries;
    await box.put(_logKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static List<AiUsageLogEntry> loadAll() {
    final raw = box.get(_logKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => AiUsageLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static int get successCountThisMonth {
    final now = DateTime.now();
    return loadAll()
        .where((e) =>
            e.at.year == now.year &&
            e.at.month == now.month &&
            e.status == 'success' &&
            e.dataTransferred)
        .length;
  }

  static double get usdThisMonth {
    final now = DateTime.now();
    return loadAll()
        .where((e) => e.at.year == now.year && e.at.month == now.month && e.status == 'success')
        .fold(0.0, (a, e) => a + e.usd);
  }

  static int get tokensThisMonth {
    final now = DateTime.now();
    return loadAll()
        .where((e) => e.at.year == now.year && e.at.month == now.month && e.status == 'success')
        .fold(0, (a, e) => a + e.inputTokens + e.outputTokens);
  }

  static Future<void> clear() => box.delete(_logKey);

  /// 호출 시점엔 아직 파싱을 안 해봐서 모르던 "이 응답을 계획으로 못 바꿨다"를
  /// 나중에 채운다 — 호출부([BlockChatParser._parseWithAi] 등)가 JSON 파싱을
  /// 시도한 뒤에만 알 수 있는 정보라 [append] 시점엔 넣을 수 없다.
  static Future<void> attachParseError(String id, String parseError) async {
    if (id.isEmpty) return;
    final list = loadAll();
    final idx = list.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    list[idx] = list[idx].copyWith(parseError: parseError);
    await box.put(_logKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  /// [feature]로 [near] 시각과 가장 가까운(±[window] 이내) 항목 — 챗
  /// 트랜스크립트(사용자 메시지 타임스탬프)와 AI 호출 로그를 연결할 때 쓴다.
  /// id를 직접 안 넘기고 시간으로 찾는 이유: [BlockChatMessage]가 지금
  /// ai_log_id를 안 들고 있어서(구조 변경 없이 기존 메시지에도 소급 적용되게
  /// 하려고 일부러 시간 매칭을 택함, 2026-[REDACTED]).
  static AiUsageLogEntry? nearestByTime(
    String feature,
    DateTime near, {
    Duration window = const Duration(seconds: 20),
  }) {
    AiUsageLogEntry? best;
    Duration? bestDiff;
    for (final e in loadAll()) {
      if (e.feature != feature) continue;
      final diff = e.at.difference(near).abs();
      if (diff > window) continue;
      if (bestDiff == null || diff < bestDiff) {
        best = e;
        bestDiff = diff;
      }
    }
    return best;
  }
}
