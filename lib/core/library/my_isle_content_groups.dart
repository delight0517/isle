import 'package:flutter/material.dart';

import 'models/library_entry.dart';

/// 나의 Isle 허브 — 저장 콘텐츠 묶음
enum MyIsleFeedKind {
  articles,
  reports,
  youtube,
}

extension MyIsleFeedKindX on MyIsleFeedKind {
  String get title => switch (this) {
        MyIsleFeedKind.articles => '나만의 기사',
        MyIsleFeedKind.reports => '나만의 리포트',
        MyIsleFeedKind.youtube => '유튜브 리포트',
      };

  String get subtitle => switch (this) {
        MyIsleFeedKind.articles => '관심·브런치·가져온 글',
        MyIsleFeedKind.reports => '다이제스트·큐레이션',
        MyIsleFeedKind.youtube => '시청·나중에 볼',
      };

  IconData get icon => switch (this) {
        MyIsleFeedKind.articles => Icons.article_outlined,
        MyIsleFeedKind.reports => Icons.insights_outlined,
        MyIsleFeedKind.youtube => Icons.play_circle_outline,
      };
}

class MyIsleContentGroups {
  MyIsleContentGroups._();

  static const _articleOrigins = {
    'interest_article',
    'brunch_sync',
    'import',
    'merged_article',
  };

  static const _reportOrigins = {
    'digest',
    'curated_suggestion',
  };

  static const _youtubeOrigins = {
    'youtube_history',
    'watch_later',
    'youtube_playlist',
    'subscription',
  };

  static Map<MyIsleFeedKind, List<LibraryEntry>> fromEntries(List<LibraryEntry> all) {
    final sorted = [...all]..sort((a, b) => b.importedAt.compareTo(a.importedAt));
    final articles = <LibraryEntry>[];
    final reports = <LibraryEntry>[];
    final youtube = <LibraryEntry>[];

    for (final e in sorted) {
      final o = e.origin;
      if (_youtubeOrigins.contains(o) || e.sourceType == 'youtube') {
        youtube.add(e);
      } else if (_reportOrigins.contains(o) || o.contains('digest')) {
        reports.add(e);
      } else if (_articleOrigins.contains(o) || e.sourceType != 'youtube') {
        articles.add(e);
      }
    }

    return {
      MyIsleFeedKind.articles: articles,
      MyIsleFeedKind.reports: reports,
      MyIsleFeedKind.youtube: youtube,
    };
  }

  static String originLabel(String origin) => switch (origin) {
        'interest_article' => '관심 기사',
        'digest' => '리포트',
        'youtube_history' => '시청',
        'watch_later' => '나중에 볼',
        'youtube_playlist' => '플레이리스트',
        'brunch_sync' => '브런치',
        'curated_suggestion' => '추천',
        'subscription' => '구독',
        _ => '저장됨',
      };
}
