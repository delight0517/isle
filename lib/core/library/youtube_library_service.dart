import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../auth/google_sign_in_config.dart';
import '../constants/env.dart';
import '../services/isle_app_log_service.dart';
import '../utils/url_parser.dart';
import 'models/library_entry.dart';
import 'models/youtube_playlist_summary.dart';

/// Google 계정 + YouTube Data API — 수동 가져오기 (로컬 저장)
class YoutubeLibraryService {
  YoutubeLibraryService._();

  static const _youtubeReadonly = 'https://www.googleapis.com/auth/youtube.readonly';

  static GoogleSignIn? _instance;

  static GoogleSignIn get _signIn {
    _instance ??= GoogleSignInConfig.isConfigured
        ? GoogleSignInConfig.create(scopes: [_youtubeReadonly])
        : GoogleSignIn(scopes: [_youtubeReadonly]);
    return _instance!;
  }

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 25),
    ),
  );

  static GoogleSignInAccount? get currentAccount {
    if (!Env.isGoogleSignInConfigured) return null;
    try {
      return _signIn.currentUser;
    } catch (_) {
      return null;
    }
  }

  static String get setupHint => GoogleSignInConfig.isConfigured
      ? 'Google Cloud에서 YouTube Data API v3를 켜고 OAuth 클라이언트를 설정하세요. ${GoogleSignInConfig.platformSetupHint}'
      : 'Google 로그인: env.dart에 googleWebClientId(권장) 또는 iOS/Android 클라이언트 ID를 넣으세요.';

  /// 설정 없이 네이티브 로그인 UI를 띄우면 iOS에서 크래시할 수 있음
  static bool get canAttemptSignIn => GoogleSignInConfig.isConfigured;

  static Future<YoutubeSignInResult> signIn() async {
    if (!canAttemptSignIn) {
      return YoutubeSignInResult(
        success: false,
        needsConfiguration: true,
        message: setupHint,
      );
    }
    try {
      final account = await _signIn.signIn();
      if (account == null) {
        return const YoutubeSignInResult(success: false, message: '로그인이 취소되었어요.');
      }
      return YoutubeSignInResult(success: true, email: account.email);
    } on PlatformException catch (e, st) {
      IsleAppLogService.log('YouTube sign-in PlatformException: $e', level: IsleLogLevel.error, stack: st);
      return YoutubeSignInResult(
        success: false,
        message: e.message ?? e.code,
      );
    } catch (e, st) {
      IsleAppLogService.log('YouTube sign-in failed: $e', level: IsleLogLevel.error, stack: st);
      return YoutubeSignInResult(success: false, message: e.toString());
    }
  }

  static Future<void> signOut() async {
    if (!canAttemptSignIn) return;
    try {
      await _signIn.signOut();
    } catch (e, st) {
      IsleAppLogService.log('YouTube sign-out failed: $e', level: IsleLogLevel.warn, stack: st);
    }
  }

  /// 몰입 모드 검색 등 Data API용 (로그인 시)
  static Future<String?> accessTokenForApi() => _accessToken();

  static Future<String?> _accessToken() async {
    if (!canAttemptSignIn) return null;
    try {
      var account = _signIn.currentUser;
      account ??= await _signIn.signInSilently();
      account ??= await _signIn.signIn();
      if (account == null) return null;
      final auth = await account.authentication;
      return auth.accessToken;
    } on PlatformException catch (e, st) {
      IsleAppLogService.log('YouTube token PlatformException: $e', level: IsleLogLevel.error, stack: st);
      return null;
    } catch (e, st) {
      IsleAppLogService.log('YouTube token failed: $e', level: IsleLogLevel.error, stack: st);
      return null;
    }
  }

  static Future<List<LibraryEntry>> fetchWatchLater({int maxResults = 50}) async {
    return fetchPlaylistEntries(
      playlistId: 'WL',
      maxResults: maxResults,
      origin: 'watch_later',
    );
  }

  /// 내 채널 플레이리스트 목록 (로그인 계정만)
  static Future<List<YoutubePlaylistSummary>> fetchMyPlaylists({int maxResults = 30}) async {
    final token = await _accessToken();
    if (token == null) {
      throw StateError(canAttemptSignIn ? 'Google 로그인이 필요합니다.' : setupHint);
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://www.googleapis.com/youtube/v3/playlists',
        queryParameters: {
          'part': 'snippet,contentDetails',
          'mine': 'true',
          'maxResults': maxResults.clamp(1, 50),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final out = <YoutubePlaylistSummary>[];
      for (final raw in res.data?['items'] as List? ?? []) {
        if (raw is! Map) continue;
        final id = raw['id'] as String?;
        if (id == null || id.isEmpty) continue;
        final snippet = raw['snippet'] as Map?;
        final details = raw['contentDetails'] as Map?;
        out.add(
          YoutubePlaylistSummary(
            id: id,
            title: snippet?['title'] as String? ?? '플레이리스트',
            itemCount: (details?['itemCount'] as num?)?.toInt() ?? 0,
            privacyStatus: snippet?['privacyStatus'] as String?,
          ),
        );
      }
      return out;
    } on DioException catch (e) {
      throw StateError(_dioErrorMessage(e));
    }
  }

  /// 특정 플레이리스트 영상 (WL·내가 만든 목록 · 비공개 포함)
  static Future<List<LibraryEntry>> fetchPlaylistEntries({
    required String playlistId,
    int maxResults = 50,
    String origin = 'youtube_playlist',
  }) async {
    final token = await _accessToken();
    if (token == null) {
      throw StateError(canAttemptSignIn
          ? 'Google 로그인이 필요합니다. 다시 로그인해 주세요.'
          : setupHint);
    }

    final entries = <LibraryEntry>[];
    String? pageToken;
    final cap = maxResults.clamp(1, 200);

    try {
      while (entries.length < cap) {
        final res = await _dio.get<Map<String, dynamic>>(
          'https://www.googleapis.com/youtube/v3/playlistItems',
          queryParameters: {
            'part': 'snippet',
            'playlistId': playlistId,
            'maxResults': (cap - entries.length).clamp(1, 50),
            if (pageToken != null) 'pageToken': pageToken,
          },
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        entries.addAll(
          _playlistItemsToEntries(
            res.data?['items'] as List?,
            origin: origin,
            playlistId: playlistId,
          ),
        );
        pageToken = res.data?['nextPageToken'] as String?;
        if (pageToken == null || pageToken.isEmpty) break;
      }
      return entries.take(cap).toList();
    } on DioException catch (e) {
      throw StateError(_dioErrorMessage(e));
    }
  }

  /// 구독 채널별 최신 영상 (최대 [maxChannels]개 채널 × [perChannel]편)
  static Future<List<LibraryEntry>> fetchSubscriptionFeed({
    int maxChannels = 10,
    int perChannel = 2,
  }) async {
    final token = await _accessToken();
    if (token == null) {
      throw StateError(canAttemptSignIn
          ? 'Google 로그인이 필요합니다.'
          : setupHint);
    }

    try {
      final subsRes = await _dio.get<Map<String, dynamic>>(
        'https://www.googleapis.com/youtube/v3/subscriptions',
        queryParameters: {
          'part': 'snippet',
          'mine': 'true',
          'maxResults': maxChannels.clamp(1, 25),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final subs = subsRes.data?['items'] as List? ?? [];
      final entries = <LibraryEntry>[];

      for (final raw in subs) {
        if (raw is! Map) continue;
        final snippet = raw['snippet'] as Map?;
        if (snippet == null) continue;
        final channelId = snippet['resourceId']?['channelId'] as String?;
        if (channelId == null || channelId.isEmpty) continue;
        final channelTitle = snippet['title'] as String? ?? '';

        try {
          final searchRes = await _dio.get<Map<String, dynamic>>(
            'https://www.googleapis.com/youtube/v3/search',
            queryParameters: {
              'part': 'snippet',
              'channelId': channelId,
              'type': 'video',
              'order': 'date',
              'maxResults': perChannel.clamp(1, 5),
            },
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
          final items = searchRes.data?['items'] as List? ?? [];
          for (final item in items) {
            if (item is! Map) continue;
            final sn = item['snippet'] as Map?;
            final vid = item['id']?['videoId'] as String?;
            if (sn == null || vid == null || vid.length != 11) continue;
            entries.add(
              LibraryEntry(
                id: 'yt_sub_$vid',
                title: sn['title'] as String? ?? 'YouTube',
                url: 'https://www.youtube.com/watch?v=$vid',
                thumbnailUrl: UrlParser.youTubeThumbnail(vid),
                sourceType: 'youtube',
                channelId: channelId,
                channelName: channelTitle,
                origin: 'subscription',
                importedAt: DateTime.now(),
                publishedAt: DateTime.tryParse(sn['publishedAt'] as String? ?? '') ?? DateTime.now(),
              ),
            );
          }
        } catch (_) {
          continue;
        }
      }
      return entries;
    } on DioException catch (e) {
      throw StateError(_dioErrorMessage(e));
    }
  }

  /// 유사 채널 검색 (YouTube Data API · 로그인 필요)
  static Future<List<({String channelId, String channelName})>> searchChannels(
    String query, {
    int maxResults = 25,
  }) async {
    final token = await _accessToken();
    if (token == null) throw StateError('Google 로그인이 필요합니다');
    final q = query.trim();
    if (q.isEmpty) return [];

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://www.googleapis.com/youtube/v3/search',
        queryParameters: {
          'part': 'snippet',
          'type': 'channel',
          'q': q,
          'maxResults': maxResults.clamp(1, 50),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final out = <({String channelId, String channelName})>[];
      for (final raw in res.data?['items'] as List? ?? []) {
        if (raw is! Map) continue;
        final id = raw['id']?['channelId'] as String?;
        final sn = raw['snippet'] as Map?;
        final title = sn?['title'] as String? ?? '';
        if (id == null || id.isEmpty) continue;
        out.add((channelId: id, channelName: title));
      }
      return out;
    } on DioException catch (e) {
      throw StateError(_dioErrorMessage(e));
    }
  }

  static String _dioErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map) {
        final msg = err['message'] as String?;
        if (msg != null && msg.isNotEmpty) return msg;
      }
    }
    if (e.response?.statusCode == 403) {
      return 'YouTube API 권한이 없어요. Cloud Console에서 YouTube Data API v3를 켜고, 나중에 볼(WL) 접근이 막힌 계정일 수 있어요.';
    }
    return e.message ?? 'YouTube API 요청 실패';
  }

  static List<LibraryEntry> _playlistItemsToEntries(
    List? items, {
    String origin = 'watch_later',
    String? playlistId,
  }) {
    final entries = <LibraryEntry>[];
    for (final raw in items ?? []) {
      if (raw is! Map) continue;
      final snippet = raw['snippet'] as Map?;
      if (snippet == null) continue;
      final resourceId = snippet['resourceId'] as Map?;
      final videoId = resourceId?['videoId'] as String?;
      if (videoId == null || videoId.length != 11) continue;
      final title = snippet['title'] as String? ?? 'YouTube';
      final channelName = snippet['channelTitle'] as String? ?? '';
      final channelId = snippet['channelId'] as String? ?? '';
      final publishedAt = DateTime.tryParse(snippet['publishedAt'] as String? ?? '');
      if (origin == 'watch_later') {
        entries.add(
          LibraryEntry.fromWatchLater(
            videoId: videoId,
            title: title,
            channelName: channelName,
            channelId: channelId,
          ),
        );
      } else {
        entries.add(
          LibraryEntry.fromYoutubePlaylist(
            videoId: videoId,
            title: title,
            channelName: channelName,
            channelId: channelId,
            playlistId: playlistId ?? '',
            publishedAt: publishedAt,
          ),
        );
      }
    }
    return entries;
  }
}

class YoutubeSignInResult {
  const YoutubeSignInResult({
    required this.success,
    this.email,
    this.message,
    this.needsConfiguration = false,
  });

  final bool success;
  final String? email;
  final String? message;
  final bool needsConfiguration;
}
