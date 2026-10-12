import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:isle/core/youtube/youtube_music_route.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Hive.init('./test/tmp_hive_music_route');
    await Hive.openBox<String>('isle_cache');
  });

  tearDown(() async {
    await Hive.box<String>('isle_cache').clear();
    await Hive.box<String>('isle_cache').close();
  });

  test('music host routes to podcast', () {
    expect(
      YoutubeMusicRoute.podcastRouteFor('https://music.youtube.com/watch?v=abc'),
      isNotNull,
    );
    expect(
      YoutubeMusicRoute.podcastRouteFor('https://www.youtube.com/playlist?list=PLtest'),
      isNotNull,
    );
    expect(
      YoutubeMusicRoute.podcastRouteFor('https://www.youtube.com/watch?v=abc'),
      isNull,
    );
  });
}
