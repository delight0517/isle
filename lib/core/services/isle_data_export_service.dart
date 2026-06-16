import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../ai/api_budget_store.dart';
import '../library/interest_pipeline_store.dart';
import '../library/models/connected_source.dart';
import '../library/models/interest_item.dart';
import '../youtube/models/channel_genre_profile.dart';
import '../youtube/models/channel_genre_sample.dart';
import '../library/models/library_entry.dart';
import '../library/personal_library_store.dart';
import '../youtube/blocked_channel_store.dart';
import '../youtube/content_filter_store.dart';
import '../youtube/models/blocked_channel.dart';
import '../youtube/models/blocked_video.dart';
import '../block_schedule/block_schedule_store.dart';
import '../block_schedule/models/block_schedule.dart';
import '../youtube/channel_genre_block_store.dart';
import '../intervention/screen_time_persistence_service.dart';
import '../youtube/youtube_watch_timer_store.dart';
import '../brunch/brunch_blocked_author_store.dart';
import '../feed/feed_boost_store.dart';
import '../feed/models/feed_boost_preference.dart';
import '../island/island_snapshot_store.dart';
import '../island/local_shelf_store.dart';
import '../social/instagram_following_store.dart';
import '../social/isle_social_store.dart';

/// 차단·라이브러리·포커스 설정 JSON — export_schema 4
class IsleDataExportService {
  IsleDataExportService._();

  static const exportSchema = 10;

  static Future<Map<String, dynamic>> buildExportPayload() async {
    await LocalShelfStore.ensureOpen();
    await BlockedChannelStore.flushPending();
    final cache = Hive.box<String>('isle_cache');
    final blocked = BlockedChannelStore.loadAll().map((e) => e.toJson()).toList();
    final videos = ContentFilterStore.loadVideos().map((e) => e.toJson()).toList();
    final keywords = ContentFilterStore.loadKeywords();
    final cacheSnapshot = <String, String>{};
    for (final key in cache.keys) {
      final v = cache.get(key);
      if (v != null) cacheSnapshot[key.toString()] = v;
    }

    final timerBox = YoutubeWatchTimerStore.box;
    final apiBox = ApiBudgetStore.box;

    return {
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'isle',
      'export_schema': exportSchema,
      'blocked_channels': blocked,
      'blocked_videos': videos,
      'blocked_keywords': keywords,
      'connected_sources': PersonalLibraryStore.loadSources().map((e) => e.toJson()).toList(),
      'library_entries': PersonalLibraryStore.loadEntries().map((e) => e.toJson()).toList(),
      'interest_pipeline': InterestPipelineStore.loadAll().map((e) => e.toJson()).toList(),
      'channel_genre_samples':
          ChannelGenreBlockStore.loadSamples().map((e) => e.toJson()).toList(),
      'channel_genre_profiles':
          ChannelGenreBlockStore.loadProfiles().map((e) => e.toJson()).toList(),
      'block_schedules': BlockScheduleStore.loadAll().map((e) => e.toJson()).toList(),
      'youtube_timer': {
        'day': timerBox.get('day_yyyy_mm_dd'),
        'seconds_used': timerBox.get('seconds_used'),
      },
      'api_budget': {
        'month': apiBox.get('budget_month'),
        'spent_usd': apiBox.get('spent_usd_month'),
        'usage_log': apiBox.get('usage_log_v1'),
      },
      'isle_cache': cacheSnapshot,
      'feed_boost_channels': FeedBoostStore.loadChannels().map((e) => e.toJson()).toList(),
      'feed_boost_genres': FeedBoostStore.loadGenres().map((e) => e.toJson()).toList(),
      'brunch_blocked_authors': BrunchBlockedAuthorStore.loadAll().map((e) => e.toJson()).toList(),
      'isle_social': IsleSocialStore.exportBundle(),
      'instagram_following': InstagramFollowingStore.loadAll().map((e) => e.toJson()).toList(),
      'local_shelves': _exportAllLocalShelves(),
      ScreenTimePersistenceService.exportKey: await ScreenTimePersistenceService.exportBundle(),
    };
  }

  static List<Map<String, dynamic>> _exportAllLocalShelves() {
    if (!LocalShelfStore.box.isOpen) return [];
    final out = <Map<String, dynamic>>[];
    for (final key in LocalShelfStore.box.keys) {
      final raw = LocalShelfStore.box.get(key);
      if (raw == null) continue;
      try {
        for (final e in jsonDecode(raw) as List) {
          if (e is Map) out.add(Map<String, dynamic>.from(e));
        }
      } catch (_) {}
    }
    return out;
  }

  static Future<void> shareExport() async {
    final json = const JsonEncoder.withIndent('  ').convert(await buildExportPayload());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/isle_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], subject: 'Isle 필터 백업');
  }

  /// Replace All 복원 전 — 사용자 데이터 초기화
  static Future<void> clearAllUserData() async {
    await BlockedChannelStore.saveAll([]);
    await ContentFilterStore.saveVideos([]);
    await ContentFilterStore.saveKeywords([]);
    await PersonalLibraryStore.saveSources([]);
    await PersonalLibraryStore.saveEntries([]);
    await BlockScheduleStore.saveAll([]);
    await InterestPipelineStore.saveAll([]);
    await ChannelGenreBlockStore.saveSamples([]);
    await ChannelGenreBlockStore.saveProfiles([]);
    await FeedBoostStore.saveChannels([]);
    await FeedBoostStore.saveGenres([]);
    await BrunchBlockedAuthorStore.saveAll([]);
    await InstagramFollowingStore.saveAll([]);
    await IsleSocialStore.box.put('posts_v1', '[]');
    await IsleSocialStore.box.put('followers_v1', '[]');
    await IsleSocialStore.box.put('following_isle_v1', '[]');
    await LocalShelfStore.ensureOpen();
    for (final key in LocalShelfStore.box.keys.toList()) {
      await LocalShelfStore.box.delete(key);
    }
    for (final key in IslandSnapshotStore.box.keys.toList()) {
      await IslandSnapshotStore.box.delete(key);
    }
  }

  /// 반환: 병합된 항목 수(대략)
  static Future<int> importFromJsonString(String raw) async {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final schema = (decoded['export_schema'] as num?)?.toInt() ?? 3;
    var count = 0;

    final blocked = decoded['blocked_channels'];
    if (blocked is List) {
      final list = BlockedChannelStore.loadAll();
      for (final item in blocked) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final id = (m['channel_id'] as String? ?? '').trim();
        final name = (m['channel_name'] as String? ?? '').trim();
        if (id.isEmpty && name.isEmpty) continue;
        final entry = BlockedChannel(
          channelId: id.isNotEmpty ? id : name,
          channelName: name.isNotEmpty ? name : id,
          blockedAt: DateTime.tryParse(m['blocked_at'] as String? ?? '') ?? DateTime.now(),
        );
        final idx = list.indexWhere(
          (c) => c.channelId == entry.channelId || c.channelName == entry.channelName,
        );
        if (idx >= 0) {
          list[idx] = entry;
        } else {
          list.add(entry);
        }
        count++;
      }
      await BlockedChannelStore.saveAll(list);
    }

    final videos = decoded['blocked_videos'];
    if (videos is List) {
      final list = ContentFilterStore.loadVideos();
      for (final item in videos) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final vid = (m['video_id'] as String? ?? '').trim();
        if (vid.length != 11) continue;
        if (list.any((e) => e.videoId == vid)) continue;
        list.add(
          BlockedVideo(
            videoId: vid,
            sourceUrl: m['source_url'] as String?,
            blockedAt: DateTime.tryParse(m['blocked_at'] as String? ?? '') ?? DateTime.now(),
          ),
        );
        count++;
      }
      await ContentFilterStore.saveVideos(list);
    }

    final kws = decoded['blocked_keywords'];
    if (kws is List) {
      final merged = ContentFilterStore.loadKeywords().toSet();
      for (final e in kws) {
        if (e is! String) continue;
        final t = e.trim().toLowerCase();
        if (t.isEmpty) continue;
        if (merged.add(t)) count++;
      }
      await ContentFilterStore.saveKeywords(merged.toList());
    }

    final sources = decoded['connected_sources'];
    if (sources is List) {
      final list = PersonalLibraryStore.loadSources();
      for (final item in sources) {
        if (item is! Map) continue;
        final s = ConnectedSource.fromJson(Map<String, dynamic>.from(item));
        if (list.any((x) => x.profileUrl == s.profileUrl)) continue;
        list.add(s);
        count++;
      }
      await PersonalLibraryStore.saveSources(list);
    }

    final entries = decoded['library_entries'];
    if (entries is List) {
      final incoming = <LibraryEntry>[];
      for (final item in entries) {
        if (item is! Map) continue;
        incoming.add(LibraryEntry.fromJson(Map<String, dynamic>.from(item)));
      }
      count += await PersonalLibraryStore.upsertEntries(incoming);
    }

    if (schema >= 6) {
      final schedules = decoded['block_schedules'];
      if (schedules is List) {
        final incoming = schedules
            .whereType<Map>()
            .map((e) => BlockSchedule.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (incoming.isNotEmpty) {
          final merged = [...BlockScheduleStore.loadAll()];
          for (final s in incoming) {
            final idx = merged.indexWhere((e) => e.id == s.id);
            if (idx >= 0) {
              merged[idx] = s;
            } else {
              merged.add(s);
            }
          }
          await BlockScheduleStore.saveAll(merged);
          count += incoming.length;
        }
      }
    }

    if (schema >= 5) {
      final genreSamples = decoded['channel_genre_samples'];
      if (genreSamples is List) {
        final incoming = genreSamples
            .whereType<Map>()
            .map((e) => ChannelGenreSample.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (incoming.isNotEmpty) {
          final merged = [...ChannelGenreBlockStore.loadSamples(), ...incoming];
          await ChannelGenreBlockStore.saveSamples(merged);
          count += incoming.length;
        }
      }
      final genreProfiles = decoded['channel_genre_profiles'];
      if (genreProfiles is List) {
        final incoming = genreProfiles
            .whereType<Map>()
            .map((e) => ChannelGenreProfile.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (incoming.isNotEmpty) {
          await ChannelGenreBlockStore.saveProfiles([
            ...incoming,
            ...ChannelGenreBlockStore.loadProfiles(),
          ]);
          count += incoming.length;
        }
      }
    }

    if (schema >= 4) {
      final pipeline = decoded['interest_pipeline'];
      if (pipeline is List && pipeline.isNotEmpty) {
        final incoming = <InterestItem>[];
        for (final item in pipeline) {
          if (item is! Map) continue;
          incoming.add(InterestItem.fromJson(Map<String, dynamic>.from(item)));
        }
        final merged = [...InterestPipelineStore.loadAll()];
        for (final item in incoming) {
          final idx = merged.indexWhere((e) => e.id == item.id);
          if (idx >= 0) {
            merged[idx] = item;
          } else {
            merged.add(item);
          }
        }
        await InterestPipelineStore.saveAll(merged);
        count += incoming.length;
      }

      final timer = decoded['youtube_timer'];
      if (timer is Map) {
        final box = YoutubeWatchTimerStore.box;
        final day = timer['day'];
        final sec = timer['seconds_used'];
        if (day is String) await box.put('day_yyyy_mm_dd', day);
        if (sec != null) await box.put('seconds_used', sec.toString());
        count++;
      }

      final budget = decoded['api_budget'];
      if (budget is Map) {
        final box = ApiBudgetStore.box;
        final month = budget['month'];
        final spent = budget['spent_usd'];
        final log = budget['usage_log'];
        if (month is String) await box.put('budget_month', month);
        if (spent != null) await box.put('spent_usd_month', spent.toString());
        if (log is String) await box.put('usage_log_v1', log);
        count++;
      }
    }

    if (schema >= 8) {
      final boostCh = decoded['feed_boost_channels'];
      if (boostCh is List) {
        final list = FeedBoostStore.loadChannels();
        for (final item in boostCh) {
          if (item is! Map) continue;
          final c = FeedBoostChannel.fromJson(Map<String, dynamic>.from(item));
          if (c.channelId.isEmpty && c.channelName.isEmpty) continue;
          if (!list.any((x) => x.matches(id: c.channelId, name: c.channelName))) {
            list.add(c);
            count++;
          }
        }
        await FeedBoostStore.saveChannels(list);
      }
      final boostGe = decoded['feed_boost_genres'];
      if (boostGe is List) {
        final list = FeedBoostStore.loadGenres();
        for (final item in boostGe) {
          if (item is! Map) continue;
          final g = FeedBoostGenre.fromJson(Map<String, dynamic>.from(item));
          if (!list.any((x) => x.id == g.id)) {
            list.add(g);
            count++;
          }
        }
        await FeedBoostStore.saveGenres(list);
      }
      final brunch = decoded['brunch_blocked_authors'];
      if (brunch is List) {
        final list = BrunchBlockedAuthorStore.loadAll();
        for (final item in brunch) {
          if (item is! Map) continue;
          final a = BrunchBlockedAuthor.fromJson(Map<String, dynamic>.from(item));
          if (a.handle.isEmpty && a.displayName.isEmpty) continue;
          if (!list.any((x) => x.handle == a.handle)) {
            list.add(a);
            count++;
          }
        }
        await BrunchBlockedAuthorStore.saveAll(list);
      }
    }

    if (schema >= 9) {
      final social = decoded['isle_social'];
      if (social is Map) {
        await IsleSocialStore.importBundle(Map<String, dynamic>.from(social));
        count++;
      }
      final ig = decoded['instagram_following'];
      if (ig is List) {
        final list = InstagramFollowingStore.loadAll();
        for (final item in ig) {
          if (item is! Map) continue;
          final e = InstagramFollowEntry.fromJson(Map<String, dynamic>.from(item));
          if (e.handle.isEmpty) continue;
          if (!list.any((x) => x.handle == e.handle)) {
            list.add(e);
            count++;
          }
        }
        await InstagramFollowingStore.saveAll(list);
      }
    }

    if (schema >= 10) {
      final st = decoded[ScreenTimePersistenceService.exportKey];
      if (st is Map) {
        await ScreenTimePersistenceService.importBundle(Map<String, dynamic>.from(st));
        count++;
      }
    }

    final cache = decoded['isle_cache'];
    if (cache is Map) {
      final box = Hive.box<String>('isle_cache');
      for (final e in cache.entries) {
        await box.put(e.key.toString(), e.value.toString());
      }
    }

    final localShelves = decoded['local_shelves'];
    if (localShelves is List && localShelves.isNotEmpty) {
      await LocalShelfStore.ensureOpen();
      final byUser = <String, List<Map<String, dynamic>>>{};
      for (final item in localShelves) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final uid = m['user_id'] as String? ?? 'local';
        byUser.putIfAbsent(uid, () => []).add(m);
      }
      for (final e in byUser.entries) {
        await LocalShelfStore.box.put('uid_${e.key}', jsonEncode(e.value));
        count += e.value.length;
      }
    }

    return count;
  }
}
