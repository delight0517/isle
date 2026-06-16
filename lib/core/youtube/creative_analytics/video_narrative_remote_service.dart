import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/env.dart';
import '../../services/isle_app_log_service.dart';
import '../../services/isle_user_defaults.dart';
import 'models/narrative_report.dart';

/// Supabase Edge Function `analyze_video` — 캐시 + 서버 LLM (키는 앱에 없음)
class VideoNarrativeRemoteService {
  VideoNarrativeRemoteService._();

  static bool get canUse =>
      Env.isSupabaseConfigured && IsleUserDefaults.creativeAnalyticsCloudEnabled;

  static Future<NarrativeReport?> analyze({
    required String videoId,
    required String title,
    required String channelName,
    required int durationSeconds,
  }) async {
    if (!canUse) return null;

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'analyze_video',
        body: {
          'videoId': videoId,
          'title': title,
          'channelName': channelName,
          'durationSeconds': durationSeconds,
        },
      );

      if (res.status != 200) {
        IsleAppLogService.log(
          'analyze_video edge ${res.status} ${res.data}',
          level: IsleLogLevel.warn,
        );
        return null;
      }

      final data = res.data;
      final Map<String, dynamic> map;
      if (data is Map) {
        map = Map<String, dynamic>.from(data);
      } else if (data is String) {
        map = Map<String, dynamic>.from(jsonDecode(data) as Map);
      } else {
        return null;
      }

      if (map['error'] != null) {
        final code = map['error'].toString();
        if (code == 'no_captions') {
          throw StateError(map['message'] as String? ?? '자막이 없어요');
        }
        return null;
      }

      return NarrativeReport.fromJson(map);
    } catch (e, st) {
      IsleAppLogService.log('analyze_video failed: $e\n$st', level: IsleLogLevel.warn);
      rethrow;
    }
  }
}
