import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/isle_user_defaults.dart';
import '../../../../core/youtube/youtube_podcast_listen_store.dart';
import '../../../../shared/widgets/isle_sheet.dart';

Future<void> showYoutubePodcastLimitSheet(BuildContext context) async {
  var enabled = YoutubePodcastListenStore.isEnabled;
  var minutes = IsleUserDefaults.youtubePodcastDailyLimitMinutes.toDouble();

  await showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setLocal) {
        final used = YoutubePodcastListenStore.secondsUsedToday ~/ 60;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('음성 모드 한도', style: IsleText.subtitle(color: IsleColors.ocean900)),
              const SizedBox(height: 6),
              Text(
                '영상 시청 한도와 별도 · 데이터 절약 모드',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              const SizedBox(height: 8),
              Text(
                '오늘 $used분 사용 · ${minutes.round()}분 한도',
                style: IsleText.body(color: IsleColors.ocean700),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('음성 한도 켜기'),
                subtitle: const Text('영상 시청 한도와 완전히 별도'),
                value: enabled,
                onChanged: (v) async {
                  await IsleUserDefaults.setYoutubePodcastLimitEnabled(v);
                  setLocal(() => enabled = v);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('숏폼(릴스) 제외'),
                subtitle: const Text('60초 이하 영상을 검색·피드에서 숨김'),
                value: IsleUserDefaults.youtubePodcastExcludeShorts,
                onChanged: (v) async {
                  await IsleUserDefaults.setYoutubePodcastExcludeShorts(v);
                  setLocal(() {});
                },
              ),
              Slider(
                value: minutes.clamp(15, 300),
                min: 15,
                max: 300,
                divisions: 57,
                label: '${minutes.round()}분',
                onChanged: enabled
                    ? (v) => setLocal(() => minutes = v)
                    : null,
              ),
              FilledButton(
                onPressed: () async {
                  await IsleUserDefaults.setYoutubePodcastDailyLimitMinutes(
                    minutes.round(),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('저장'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
