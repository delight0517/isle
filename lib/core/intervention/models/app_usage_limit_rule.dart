/// 외부 앱 사용 한도 + 개입(쉴드/전면 안내)
class AppUsageLimitRule {
  const AppUsageLimitRule({
    required this.id,
    required this.label,
    required this.minutesPerWindow,
    this.enabled = true,
    this.iosFamilyActivityEncoded,
    this.androidPackageName,
    this.presetId,
    this.scheduleId,
    this.windowMinutes = 1440,
    this.interventionTitle = '오늘 한도에 도달했어요',
    this.interventionBody = '잠시 쉬었다가 Isle에서 의도한 콘텐츠만 보세요.',
  });

  final String id;
  final String label;
  final int minutesPerWindow;
  final bool enabled;
  final String? iosFamilyActivityEncoded;
  final String? androidPackageName;
  final String? presetId;
  final String? scheduleId;
  final int windowMinutes; // 60 = 매시간 리셋, 1440 = 일일 리셋
  final String interventionTitle;
  final String interventionBody;

  static const instagramPreset = (
    id: 'instagram',
    label: 'Instagram',
    androidPackage: 'com.instagram.android',
  );
  static const tiktokPreset = (
    id: 'tiktok',
    label: 'TikTok',
    androidPackage: 'com.zhiliaoapp.musically',
  );
  static const youtubeAppPreset = (
    id: 'youtube_app',
    label: 'YouTube 앱',
    androidPackage: 'com.google.android.youtube',
  );

  static const presets = [instagramPreset, tiktokPreset, youtubeAppPreset];

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'minutes_per_window': minutesPerWindow,
        'enabled': enabled,
        if (iosFamilyActivityEncoded != null)
          'ios_encoded': iosFamilyActivityEncoded,
        if (androidPackageName != null) 'android_package': androidPackageName,
        if (presetId != null) 'preset_id': presetId,
        if (scheduleId != null) 'schedule_id': scheduleId,
        'window_minutes': windowMinutes,
        'intervention_title': interventionTitle,
        'intervention_body': interventionBody,
      };

  factory AppUsageLimitRule.fromJson(Map<String, dynamic> j) => AppUsageLimitRule(
        id: j['id'] as String? ?? '',
        label: j['label'] as String? ?? '앱',
        minutesPerWindow: (j['minutes_per_window'] as num?)?.toInt() ??
            (j['minutes_per_day'] as num?)?.toInt() ??
            20,
        enabled: j['enabled'] as bool? ?? true,
        iosFamilyActivityEncoded: j['ios_encoded'] as String?,
        androidPackageName: j['android_package'] as String?,
        presetId: j['preset_id'] as String?,
        scheduleId: j['schedule_id'] as String?,
        windowMinutes: (j['window_minutes'] as num?)?.toInt() ?? 1440,
        interventionTitle: j['intervention_title'] as String? ?? '오늘 한도에 도달했어요',
        interventionBody: j['intervention_body'] as String? ??
            '잠시 쉬었다가 Isle에서 의도한 콘텐츠만 보세요.',
      );

  AppUsageLimitRule copyWith({
    String? label,
    int? minutesPerWindow,
    bool? enabled,
    String? iosFamilyActivityEncoded,
    String? androidPackageName,
    String? scheduleId,
    int? windowMinutes,
  }) =>
      AppUsageLimitRule(
        id: id,
        label: label ?? this.label,
        minutesPerWindow: minutesPerWindow ?? this.minutesPerWindow,
        enabled: enabled ?? this.enabled,
        iosFamilyActivityEncoded: iosFamilyActivityEncoded ?? this.iosFamilyActivityEncoded,
        androidPackageName: androidPackageName ?? this.androidPackageName,
        presetId: presetId,
        scheduleId: scheduleId ?? this.scheduleId,
        windowMinutes: windowMinutes ?? this.windowMinutes,
        interventionTitle: interventionTitle,
        interventionBody: interventionBody,
      );
}
