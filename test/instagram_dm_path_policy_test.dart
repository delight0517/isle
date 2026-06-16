import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/social/instagram_dm_path_policy.dart';

void main() {
  test('allows DM thread and inbox', () {
    expect(InstagramDmPathPolicy.isAllowedInDmFocusMode('/direct/inbox/'), isTrue);
    expect(InstagramDmPathPolicy.isDmThreadPath('/direct/t/12345/'), isTrue);
  });

  test('allows counterpart profile posts and stories', () {
    expect(InstagramDmPathPolicy.isProfileOrStoriesPath('/some_friend/'), isTrue);
    expect(InstagramDmPathPolicy.isProfileOrStoriesPath('/some_friend/reels/'), isTrue);
    expect(InstagramDmPathPolicy.isProfileOrStoriesPath('/stories/some_friend/'), isTrue);
    expect(InstagramDmPathPolicy.isAllowedInDmFocusMode('/some_friend/'), isTrue);
  });

  test('blocks home feed and explore', () {
    expect(InstagramDmPathPolicy.isAllowedInDmFocusMode('/'), isFalse);
    expect(InstagramDmPathPolicy.isAllowedInDmFocusMode('/explore/'), isFalse);
    expect(InstagramDmPathPolicy.isAllowedInDmFocusMode('/reels/'), isFalse);
  });

  test('allows shared post links from DM', () {
    expect(InstagramDmPathPolicy.isSharedMediaPath('/p/ABC123/'), isTrue);
    expect(InstagramDmPathPolicy.isAllowedInDmFocusMode('/reel/xyz/'), isTrue);
  });
}
