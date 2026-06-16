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
      };

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
}
