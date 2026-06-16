/// 스케줄 URL·단어 규칙 종류 (4VPN Blueprint §2.1)
enum ScheduleRuleKind {
  host,
  wildcard,
  urlContains,
  keyword,
  channelUrl,
  videoUrl,
  genreKeyword,
}

extension ScheduleRuleKindX on ScheduleRuleKind {
  String get storageKey => switch (this) {
        ScheduleRuleKind.host => 'host',
        ScheduleRuleKind.wildcard => 'wildcard',
        ScheduleRuleKind.urlContains => 'url_contains',
        ScheduleRuleKind.keyword => 'keyword',
        ScheduleRuleKind.channelUrl => 'channel_url',
        ScheduleRuleKind.videoUrl => 'video_url',
        ScheduleRuleKind.genreKeyword => 'genre_keyword',
      };

  static ScheduleRuleKind parse(String? raw) => switch (raw) {
        'host' => ScheduleRuleKind.host,
        'wildcard' => ScheduleRuleKind.wildcard,
        'url_contains' => ScheduleRuleKind.urlContains,
        'keyword' => ScheduleRuleKind.keyword,
        'channel_url' => ScheduleRuleKind.channelUrl,
        'video_url' => ScheduleRuleKind.videoUrl,
        'genre_keyword' => ScheduleRuleKind.genreKeyword,
        _ => ScheduleRuleKind.host,
      };

  String get labelKo => switch (this) {
        ScheduleRuleKind.host => '사이트 전체',
        ScheduleRuleKind.wildcard => '와일드카드',
        ScheduleRuleKind.urlContains => '주소 포함',
        ScheduleRuleKind.keyword => '키워드',
        ScheduleRuleKind.channelUrl => 'YouTube 채널',
        ScheduleRuleKind.videoUrl => 'YouTube 영상',
        ScheduleRuleKind.genreKeyword => '장르 키워드',
      };

  bool get appliesDns => this == ScheduleRuleKind.host || this == ScheduleRuleKind.wildcard;

  bool get appliesUrlParts => this == ScheduleRuleKind.urlContains;
}
