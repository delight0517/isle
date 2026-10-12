import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:isle/core/youtube/youtube_podcast_saved_playlist_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Hive.init('./test/tmp_hive_podcast_pl');
    await YoutubePodcastSavedPlaylistStore.ensureOpen();
    await YoutubePodcastSavedPlaylistStore.box.clear();
  });

  tearDown(() async {
    await YoutubePodcastSavedPlaylistStore.box.clear();
    await YoutubePodcastSavedPlaylistStore.box.close();
  });

  test('create add link and delete playlist', () async {
    expect(YoutubePodcastSavedPlaylistStore.isOpen, isTrue);
    final p = await YoutubePodcastSavedPlaylistStore.create('테스트');
    expect(YoutubePodcastSavedPlaylistStore.loadAll(), hasLength(1));

    final ok = await YoutubePodcastSavedPlaylistStore.addLink(
      playlistId: p.id,
      url: 'https://youtu.be/abc123',
    );
    expect(ok, isTrue);
    expect(YoutubePodcastSavedPlaylistStore.loadAll().first.links, hasLength(1));

    await YoutubePodcastSavedPlaylistStore.deletePlaylist(p.id);
    expect(YoutubePodcastSavedPlaylistStore.loadAll(), isEmpty);
  });
}
