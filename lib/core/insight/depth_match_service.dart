import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'insight_portfolio_store.dart';
import 'models/insight_card.dart';

class DepthMatchPeer {
  const DepthMatchPeer({
    required this.id,
    required this.displayName,
    required this.headline,
    required this.sharedKeywords,
    required this.differentNote,
    required this.sampleTitle,
    required this.depthScore,
  });

  final String id;
  final String displayName;
  final String headline;
  final List<String> sharedKeywords;
  final String differentNote;
  final String sampleTitle;
  final double depthScore;
}

/// 로컬 휴리스틱 + 시드 피어 — 관심 깊이 매칭 (서버 없음)
class DepthMatchService {
  DepthMatchService._();

  static const _boxName = 'isle_insight_portfolio';
  static const _peersKey = 'depth_peers_v1';

  static Future<void> ensureSeedPeers() async {
    await InsightPortfolioStore.ensureOpen();
    final box = Hive.box<String>(_boxName);
    if (box.get(_peersKey) != null) return;
    final seeds = [
      {
        'id': 'peer_flutter',
        'display_name': '민지',
        'headline': 'Flutter · 공간 데이터',
        'keywords': ['Flutter', 'UI', '아키텍처'],
        'note': '영상은 UI 패턴에 집중했지만, 나는 상태관리와 테스트 쪽으로 읽었어요.',
        'title': 'Widget composition deep dive',
      },
      {
        'id': 'peer_climate',
        'display_name': 'Alex',
        'headline': '어반 · 기후 솔루션',
        'keywords': ['기후', '도시', '데이터'],
        'note': '같은 TED를 봤는데, 정책 프레임보다 시민 과학 관점이 더 와닿았어요.',
        'title': 'Urban heat island solutions',
      },
      {
        'id': 'peer_design',
        'display_name': '하린',
        'headline': '타이포 · 제품 디자인',
        'keywords': ['디자인', '타이포', 'UX'],
        'note': '레퍼런스는 비슷한데, 나는 접근성 체크리스트로 재구성했어요.',
        'title': 'Minimal type in mobile apps',
      },
    ];
    await box.put(_peersKey, jsonEncode(seeds));
  }

  static List<DepthMatchPeer> findMatches({int limit = 12}) {
    final myKeywords = <String, int>{};
    for (final c in InsightPortfolioStore.published()) {
      for (final k in c.keywords) {
        myKeywords[k] = (myKeywords[k] ?? 0) + 1;
      }
    }
    if (myKeywords.isEmpty) {
      for (final c in InsightPortfolioStore.timeline(limit: 20)) {
        for (final k in c.keywords) {
          myKeywords[k] = (myKeywords[k] ?? 0) + 1;
        }
      }
    }

    final box = Hive.box<String>(_boxName);
    final raw = box.get(_peersKey);
    if (raw == null) return [];
    List<dynamic> seeds;
    try {
      seeds = jsonDecode(raw) as List;
    } catch (_) {
      return [];
    }

    final out = <DepthMatchPeer>[];
    for (final s in seeds) {
      if (s is! Map) continue;
      final map = Map<String, dynamic>.from(s);
      final peerKeys = List<String>.from(map['keywords'] as List? ?? []);
      final shared = peerKeys.where((k) => myKeywords.containsKey(k)).toList();
      if (shared.isEmpty && myKeywords.isNotEmpty) continue;
      final overlap = shared.isEmpty
          ? 0.35
          : shared.length / (peerKeys.length + myKeywords.length).clamp(1, 99);
      out.add(
        DepthMatchPeer(
          id: map['id'] as String? ?? '',
          displayName: map['display_name'] as String? ?? '탐색자',
          headline: map['headline'] as String? ?? '',
          sharedKeywords: shared.isEmpty ? peerKeys.take(2).toList() : shared,
          differentNote: map['note'] as String? ?? '',
          sampleTitle: map['title'] as String? ?? '',
          depthScore: overlap,
        ),
      );
    }
    out.sort((a, b) => b.depthScore.compareTo(a.depthScore));
    return out.take(limit).toList();
  }
}
