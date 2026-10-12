import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../services/isle_user_defaults.dart';
import 'blue_cloud_account_service.dart';

/// Strict, expiring read-only view of the Mac's currently active 4VPN rules.
/// The source sends the full schedules for inspection, while enforcement uses
/// only its current active snapshot; if the Mac stops syncing, MOA fails open.
class MoaFourVpnRulesSnapshot {
  const MoaFourVpnRulesSnapshot({
    required this.revision,
    required this.generatedAt,
    required this.timeZone,
    required this.systemBlockEnabled,
    required this.domains,
    required this.urlParts,
    required this.exceptions,
    required this.videos,
    required this.channels,
    required this.keywords,
    required this.rules,
    required this.schedules,
  });

  static const maxAge = Duration(minutes: 3);
  final int revision;
  final DateTime generatedAt;
  final String timeZone;
  final bool systemBlockEnabled;
  final List<String> domains;
  final List<String> urlParts;
  final List<String> exceptions;
  final List<String> videos;
  final List<String> channels;
  final List<String> keywords;
  final List<Map<String, dynamic>> rules;
  final List<Map<String, dynamic>> schedules;

  static MoaFourVpnRulesSnapshot? parse(Map<String, dynamic> value,
      {required DateTime now}) {
    if (value['schemaVersion'] != 1 || value['source'] != '4vpn-mac') {
      return null;
    }
    final revision = value['_rev'];
    if (revision is! int || revision < 1) return null;
    final generatedAt =
        DateTime.tryParse(value['generatedAt'] as String? ?? '');
    final timeZone = value['timeZone'];
    if (generatedAt == null ||
        timeZone is! String ||
        timeZone.isEmpty ||
        generatedAt.isAfter(now.add(const Duration(minutes: 1))) ||
        now.difference(generatedAt) > maxAge) {
      return null;
    }
    List<String>? strings(String key) {
      final raw = value[key];
      if (raw is! List ||
          raw.length > 2000 ||
          raw.any((item) => item is! String)) {
        return null;
      }
      return raw
          .map((item) => (item as String).trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final domains = strings('blockedDomains');
    final parts = strings('blockedUrlParts');
    final exceptions = strings('exceptions');
    final videos = strings('blockedVideos');
    final channels = strings('blockedChannels');
    final keywords = strings('blockedKeywords');
    List<Map<String, dynamic>>? records(String key, int maxLength) {
      final raw = value[key];
      if (raw is! List ||
          raw.length > maxLength ||
          raw.any((item) => item is! Map)) {
        return null;
      }
      return raw
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
    }

    final rules = records('rules', 20000);
    final schedules = records('schedules', 1000);
    if (value['systemBlockEnabled'] is! bool ||
        domains == null ||
        parts == null ||
        exceptions == null ||
        videos == null ||
        channels == null ||
        keywords == null ||
        rules == null ||
        schedules == null ||
        rules.any((rule) =>
            rule['id'] is! String ||
            (rule['id'] as String).isEmpty ||
            rule['pattern'] is! String ||
            rule['kind'] is! String ||
            rule['enabled'] is! bool ||
            (rule['scheduleId'] != null && rule['scheduleId'] is! String)) ||
        schedules.any((schedule) =>
            schedule['id'] is! String ||
            (schedule['id'] as String).isEmpty ||
            schedule['name'] is! String ||
            schedule['enabled'] is! bool ||
            schedule['blockAlways'] is! bool ||
            schedule['slotsJSON'] is! String ||
            schedule['calendarSlotsJSON'] is! String ||
            (schedule['dailyCapMinutes'] != null &&
                schedule['dailyCapMinutes'] is! num) ||
            schedule['usageBudgetPolicyJSON'] is! String)) {
      return null;
    }
    return MoaFourVpnRulesSnapshot(
      revision: revision,
      generatedAt: generatedAt,
      timeZone: timeZone,
      systemBlockEnabled: value['systemBlockEnabled'] as bool,
      domains: domains,
      urlParts: parts,
      exceptions: exceptions,
      videos: videos,
      channels: channels,
      keywords: keywords,
      rules: rules,
      schedules: schedules,
    );
  }

  bool blocksUrl(String rawUrl) {
    if (!systemBlockEnabled) return false;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    bool hostMatches(String pattern) =>
        host == pattern || host.endsWith('.$pattern');
    if (exceptions.any(hostMatches)) return false;
    if (domains.any(hostMatches)) return true;
    final normalizedUrl = rawUrl.toLowerCase();
    if (urlParts.any(normalizedUrl.contains)) return true;
    if (host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtu.be') {
      return videos.any(normalizedUrl.contains) ||
          channels.any(normalizedUrl.contains) ||
          keywords.any(normalizedUrl.contains);
    }
    return false;
  }
}

class MoaFourVpnRulesService {
  MoaFourVpnRulesService._();
  static const _cacheKey = 'moa_four_vpn_rules_cache_v1';
  static const _cacheAccountKey = 'moa_four_vpn_rules_account_v1';
  static MoaFourVpnRulesSnapshot? _memoryCache;

  static bool get enabled => IsleUserDefaults.fourVpnSafariRulesEnabled;

  static Future<void> setEnabled(bool value) async {
    await IsleUserDefaults.setFourVpnSafariRulesEnabled(value);
    if (!value) await _clearCache();
  }

  static Future<void> _clearCache() async {
    _memoryCache = null;
    if (Hive.isBoxOpen('isle_cache')) {
      await Hive.box<String>('isle_cache').delete(_cacheKey);
      await Hive.box<String>('isle_cache').delete(_cacheAccountKey);
    }
  }

  static MoaFourVpnRulesSnapshot? current({DateTime? now}) {
    if (!enabled) return null;
    final time = now ?? DateTime.now();
    final cached = _memoryCache;
    if (cached != null &&
        time.difference(cached.generatedAt) <= MoaFourVpnRulesSnapshot.maxAge) {
      return cached;
    }
    if (!Hive.isBoxOpen('isle_cache')) return null;
    final raw = Hive.box<String>('isle_cache').get(_cacheKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      _memoryCache = MoaFourVpnRulesSnapshot.parse(
        Map<String, dynamic>.from(decoded),
        now: time,
      );
      return _memoryCache;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> refresh({BlueCloudAccountService? account}) async {
    if (!enabled) return false;
    final client = account ?? BlueCloudAccountService();
    try {
      final username = await client.username();
      if (username == null || username.isEmpty) {
        await _clearCache();
        return false;
      }
      final box = Hive.box<String>('isle_cache');
      if (box.get(_cacheAccountKey) != null &&
          box.get(_cacheAccountKey) != username) {
        await _clearCache();
      }
      final state = await client.fetchFourVpnRulesSnapshot();
      final snapshot =
          MoaFourVpnRulesSnapshot.parse(state, now: DateTime.now());
      if (snapshot == null) return false;
      final currentSnapshot = current();
      if (currentSnapshot != null &&
          currentSnapshot.revision > snapshot.revision) {
        return false;
      }
      await box.put(_cacheKey, jsonEncode(state));
      await box.put(_cacheAccountKey, username);
      _memoryCache = snapshot;
      return true;
    } on BlueCloudAccountException catch (error) {
      if (error.code == 'login_required') await _clearCache();
      return false;
    } catch (_) {
      return false;
    } finally {
      if (account == null) client.close();
    }
  }
}
