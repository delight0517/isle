import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_user_defaults.dart';
import 'ai_client.dart';

/// OpenAI 호환 API 월 예산·사용량 추정 (로컬만)
class ApiBudgetStore {
  ApiBudgetStore._();

  static const _boxName = 'isle_api_budget';
  static const _spentKey = 'spent_usd_month';
  static const _monthKey = 'budget_month';
  static const _logKey = 'usage_log_v1';

  static Box<String>? _box;

  static Future<void> ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box {
    final b = _box;
    if (b == null || !b.isOpen) throw StateError('ApiBudgetStore not open');
    return b;
  }

  static String _monthId() {
    final n = DateTime.now();
    return '${n.year}-${n.month}';
  }

  static void _ensureMonth() {
    if (box.get(_monthKey) != _monthId()) {
      box.put(_monthKey, _monthId());
      box.put(_spentKey, '0');
    }
  }

  static double get monthlyBudgetUsd => IsleUserDefaults.apiMonthlyBudgetUsd;

  static double get spentThisMonthUsd {
    _ensureMonth();
    return double.tryParse(box.get(_spentKey) ?? '') ?? 0;
  }

  static double get remainingUsd => (monthlyBudgetUsd - spentThisMonthUsd).clamp(0, monthlyBudgetUsd);

  /// gpt-4o-mini 대략 단가 (USD / 1M tokens)
  static double estimateCostUsd({required int inputTokens, required int outputTokens}) {
    const inputPerM = 0.15;
    const outputPerM = 0.60;
    return (inputTokens / 1e6) * inputPerM + (outputTokens / 1e6) * outputPerM;
  }

  static bool canAffordEstimate(double estimatedUsd) {
    if (!AiClient.isConfigured) return false;
    if (!IsleUserDefaults.apiBudgetEnforced) return true;
    return spentThisMonthUsd + estimatedUsd <= monthlyBudgetUsd;
  }

  static Future<void> recordSpend(double usd, String reason) async {
    if (usd <= 0) return;
    _ensureMonth();
    final next = spentThisMonthUsd + usd;
    box.put(_spentKey, next.toString());

    final log = loadLog();
    log.insert(
      0,
      {
        'at': DateTime.now().toIso8601String(),
        'usd': usd,
        'reason': reason,
        'total': next,
      },
    );
    if (log.length > 100) log.length = 100;
    await box.put(_logKey, jsonEncode(log));
  }

  static List<Map<String, dynamic>> loadLog() {
    final raw = box.get(_logKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }
}
