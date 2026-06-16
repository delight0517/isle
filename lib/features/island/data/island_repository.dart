import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/env.dart';
import 'models/shelf.dart';
import 'models/archive.dart';

class IslandRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Shelf>> getShelves(String userId) async {
    if (!Env.isSupabaseConfigured || userId.isEmpty) return dummyShelves();
    final res = await _client.from('shelves').select().eq('user_id', userId);
    return (res as List).map((e) => Shelf.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Shelf> createShelf(Shelf shelf) async {
    if (!Env.isSupabaseConfigured) {
      throw StateError('Supabase가 설정되지 않았습니다.');
    }
    final res = await _client.from('shelves').insert(shelf.toJson()).select().single();
    return Shelf.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<Archive>> getArchives(String shelfId) async {
    if (!Env.isSupabaseConfigured) {
      return dummyArchives(shelfId);
    }
    final res = await _client.from('archives').select().eq('shelf_id', shelfId).order('archived_at', ascending: false);
    return (res as List).map((e) => Archive.fromJson(e as Map<String, dynamic>)).toList();
  }

  static List<Archive> dummyArchives(String shelfId) => List.generate(
        4,
        (i) => Archive(
          id: 'a$i',
          userId: '',
          shelfId: shelfId,
          url: 'https://youtube.com/watch?v=example$i',
          title: [
            'Flutter CustomPainter 완전정복',
            '2026 ETF 투자 전략',
            'Figma 프로토타이핑 팁',
            '생산성 시스템 구축하기',
          ][i],
          thumbnailUrl: 'https://picsum.photos/seed/${shelfId}_$i/120/80',
          sourceType: i % 2 == 0 ? 'youtube' : 'article',
          archivedAt: DateTime.now().subtract(Duration(days: i)),
        ),
      );

  static List<Shelf> dummyShelves() => [
        Shelf(
          id: 's1',
          userId: '',
          title: '기술/IT',
          positionX: 0,
          positionY: 1,
          colorHex: '#2B4A8C',
          iconEmoji: '💻',
          createdAt: DateTime.now(),
        ),
        Shelf(
          id: 's2',
          userId: '',
          title: '재무',
          positionX: 2,
          positionY: 0,
          colorHex: '#2ECC71',
          iconEmoji: '💰',
          createdAt: DateTime.now(),
        ),
        Shelf(
          id: 's3',
          userId: '',
          title: '디자인',
          positionX: 1,
          positionY: 2,
          colorHex: '#E8A838',
          iconEmoji: '🎨',
          createdAt: DateTime.now(),
        ),
      ];
}
