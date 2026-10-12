import '../../block_schedule/models/block_schedule.dart';

/// 나눠쓰기(usage_budget/youtube_budget/music_foreground_limit) 대상 태그 —
/// 겹치는 기존 스케줄을 찾을 때 파서·executor가 같은 기준으로 매칭하도록
/// 공유한다(2026-07-11, "전부 덮어쓸까요" 확인 흐름).
class BlockChatRationTag {
  BlockChatRationTag._();

  static bool matches(BlockSchedule s, String tag) {
    final name = s.name.toLowerCase();
    switch (tag) {
      case 'youtube_music':
        return name.contains('뮤직') || name.contains('music') || name.contains('ytm');
      case 'youtube':
        return (name.contains('유튜브') || name.contains('youtube')) &&
            !name.contains('뮤직') &&
            !name.contains('music');
      case 'instagram':
        return name.contains('인스타') || name.contains('instagram');
      case 'brunch':
        return name.contains('브런치') || name.contains('brunch');
      case 'kakao':
      case 'kakaotalk':
        return name.contains('카카오') || name.contains('카톡');
      case 'tiktok':
        return name.contains('틱톡') || name.contains('tiktok');
      case 'safari':
        return name.contains('사파리') || name.contains('safari') || s.blockIsleInApp;
      default:
        return name.contains(tag);
    }
  }

  static String label(String tag) {
    switch (tag) {
      case 'youtube_music':
        return 'YouTube Music';
      case 'youtube':
        return '유튜브';
      case 'instagram':
        return 'Instagram';
      case 'brunch':
        return 'Brunch';
      case 'kakao':
      case 'kakaotalk':
        return '카카오톡';
      case 'tiktok':
        return 'TikTok';
      case 'safari':
        return 'Safari';
      default:
        return tag;
    }
  }
}
