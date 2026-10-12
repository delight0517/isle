import '../services/isle_user_defaults.dart';
import 'models/library_entry.dart';
import 'personal_library_store.dart';

/// MOA 내부 플레이어에서 재생 중이라고 확인된 시간만 개인 라이브러리에 기록한다.
/// 기록은 로컬 전용이며, 15초 단위로 저장하고 화면을 나갈 때 남은 시간을 flush한다.
class YoutubeWatchHistoryService {
  YoutubeWatchHistoryService._();

  static const _flushEverySeconds = 15;
  static String? _activeVideoId;
  static String? _activeUrl;
  static String _channelId = '';
  static String _channelName = '';
  static String _title = '';
  static int _pendingSeconds = 0;
  static DateTime? _lastWatchedAt;

  static Future<void> recordPlaybackTick({
    required String videoId,
    required String url,
    required int seconds,
    String channelId = '',
    String channelName = '',
    String title = '',
  }) async {
    final parsedUrl = Uri.tryParse(url);
    if (!IsleUserDefaults.trackYoutubeWatchHistory) {
      await flushPending();
      return;
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId) ||
        seconds < 1 ||
        parsedUrl == null ||
        parsedUrl.scheme != 'https' ||
        parsedUrl.host != 'www.youtube.com' ||
        parsedUrl.path != '/watch' ||
        parsedUrl.queryParameters['v'] != videoId) {
      return;
    }
    if (_activeVideoId != videoId) await flushPending();
    _activeVideoId = videoId;
    _activeUrl = 'https://www.youtube.com/watch?v=$videoId';
    if (channelId.isNotEmpty) _channelId = channelId;
    if (channelName.isNotEmpty) _channelName = channelName;
    if (title.isNotEmpty) _title = title;
    _pendingSeconds += seconds.clamp(1, 5).toInt();
    _lastWatchedAt = DateTime.now();
    if (_pendingSeconds >= _flushEverySeconds) await flushPending();
  }

  static Future<void> flushPending() async {
    final videoId = _activeVideoId;
    final url = _activeUrl;
    final seconds = _pendingSeconds;
    final lastWatchedAt = _lastWatchedAt;
    if (videoId == null ||
        url == null ||
        seconds <= 0 ||
        lastWatchedAt == null) {
      _resetPending();
      return;
    }

    final entries = PersonalLibraryStore.loadEntries();
    final id = 'yt_hist_$videoId';
    final index = entries.indexWhere((entry) => entry.id == id);
    if (index < 0) {
      entries.add(LibraryEntry.fromWatchHistory(
        videoId: videoId,
        title: _title.isEmpty ? 'YouTube 영상' : _title,
        channelId: _channelId,
        channelName: _channelName,
        watchSeconds: seconds,
        lastWatchedAt: lastWatchedAt,
      ));
    } else {
      final previous = entries[index];
      entries[index] = previous.copyWith(
        title: _title.isEmpty || _title == 'YouTube 영상' ? null : _title,
        channelId: _channelId.isEmpty ? null : _channelId,
        channelName: _channelName.isEmpty ? null : _channelName,
        watchSeconds: previous.watchSeconds + seconds,
        lastWatchedAt: lastWatchedAt,
      );
    }
    await PersonalLibraryStore.saveEntries(entries);
    _resetPending();
  }

  /// 채널 probe는 재생 시간으로 계산하지 않고, 기존 시청 레코드의 표시 정보만 보강한다.
  static Future<void> attachChannelInfo({
    required String videoId,
    String channelId = '',
    String channelName = '',
    String videoTitle = '',
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)) return;
    if (_activeVideoId == videoId) {
      if (channelId.isNotEmpty) _channelId = channelId;
      if (channelName.isNotEmpty) _channelName = channelName;
      if (videoTitle.isNotEmpty) _title = videoTitle;
    }
    final entries = PersonalLibraryStore.loadEntries();
    final index = entries.indexWhere((entry) => entry.id == 'yt_hist_$videoId');
    if (index < 0) return;
    final previous = entries[index];
    if ((videoTitle.isEmpty || previous.title == videoTitle) &&
        (channelId.isEmpty || previous.channelId == channelId) &&
        (channelName.isEmpty || previous.channelName == channelName)) {
      return;
    }
    entries[index] = previous.copyWith(
      title: videoTitle.isEmpty ? null : videoTitle,
      channelId: channelId.isEmpty ? null : channelId,
      channelName: channelName.isEmpty ? null : channelName,
    );
    await PersonalLibraryStore.saveEntries(entries);
  }

  static Future<int> clearHistory() async {
    await flushPending();
    final entries = PersonalLibraryStore.loadEntries();
    final remaining =
        entries.where((entry) => entry.origin != 'youtube_history').toList();
    final removed = entries.length - remaining.length;
    await PersonalLibraryStore.saveEntries(remaining);
    _resetPending();
    return removed;
  }

  static void _resetPending() {
    _activeVideoId = null;
    _activeUrl = null;
    _channelId = '';
    _channelName = '';
    _title = '';
    _pendingSeconds = 0;
    _lastWatchedAt = null;
  }

  static void resetForTest() => _resetPending();
}
