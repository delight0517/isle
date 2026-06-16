import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/env.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/youtube/blocked_channel_store.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../feed/providers/feed_provider.dart';

class YoutubeFilterSettingsScreen extends ConsumerStatefulWidget {
  const YoutubeFilterSettingsScreen({super.key});

  @override
  ConsumerState<YoutubeFilterSettingsScreen> createState() =>
      _YoutubeFilterSettingsScreenState();
}

class _YoutubeFilterSettingsScreenState extends ConsumerState<YoutubeFilterSettingsScreen> {
  bool _webShell = IsleUserDefaults.useYoutubeWebShell;
  bool _hideFeed = IsleUserDefaults.hideBlockedInFeed;
  bool _dismissKb = IsleUserDefaults.dismissKeyboardOnBlockSheet;
  bool _desktop = IsleUserDefaults.youtubeUseDesktopSite;
  bool _cloudSync = IsleUserDefaults.syncBlockedChannelsToCloud;
  String _swipe = IsleUserDefaults.swipeRightAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IsleAppBar(title: '유튜브 필터 설정'),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline, color: IsleColors.ocean500),
            title: Text('차단 범위 안내', style: IsleText.body()),
            subtitle: Text(
              'Isle 피드/목록에서 숨김은 가능하지만, YouTube 앱 자체 검색 결과를 시스템적으로 삭제하진 못해요.',
              style: IsleText.caption(color: IsleColors.muted),
            ),
          ),
          SwitchListTile(
            title: Text('영상도 앱 안에서 재생', style: IsleText.body()),
            subtitle: Text('차단 필터 함께 적용', style: IsleText.caption()),
            value: _webShell,
            onChanged: (v) async {
              await IsleUserDefaults.setUseYoutubeWebShell(v);
              setState(() => _webShell = v);
            },
          ),
          SwitchListTile(
            title: Text('피드에서 차단 채널 숨김', style: IsleText.body()),
            value: _hideFeed,
            onChanged: (v) async {
              await IsleUserDefaults.setHideBlockedInFeed(v);
              setState(() => _hideFeed = v);
              ref.invalidate(feedProvider);
            },
          ),
          SwitchListTile(
            title: Text('차단 시트에서 키보드 내리기', style: IsleText.body()),
            value: _dismissKb,
            onChanged: (v) async {
              await IsleUserDefaults.setDismissKeyboardOnBlockSheet(v);
              setState(() => _dismissKb = v);
            },
          ),
          if (!Platform.isIOS)
            SwitchListTile(
              title: Text('데스크톱 사이트', style: IsleText.body()),
              value: _desktop,
              onChanged: (v) async {
                await IsleUserDefaults.setYoutubeUseDesktopSite(v);
                setState(() => _desktop = v);
              },
            ),
          if (Env.isSupabaseConfigured)
            SwitchListTile(
              title: Text('차단 목록 클라우드 동기화', style: IsleText.body()),
              subtitle: Text('Supabase에 로그인 시 기기 간 공유', style: IsleText.caption()),
              value: _cloudSync,
              onChanged: (v) async {
                await IsleUserDefaults.setSyncBlockedChannelsToCloud(v);
                setState(() => _cloudSync = v);
                if (v) {
                  await ref.read(blockedChannelsProvider.notifier).syncWithCloud();
                }
              },
            ),
          ListTile(
            title: Text('오른쪽 스와이프 동작', style: IsleText.body()),
            subtitle: Text(_swipeLabel(_swipe), style: IsleText.caption(color: IsleColors.muted)),
            trailing: const Icon(Icons.chevron_right, color: IsleColors.muted),
            onTap: () => _pickSwipeAction(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_sync, color: IsleColors.ocean500),
            title: Text('지금 동기화', style: IsleText.body()),
            enabled: Env.isSupabaseConfigured && _cloudSync,
            onTap: () async {
              await ref.read(blockedChannelsProvider.notifier).syncWithCloud();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('차단 목록을 동기화했습니다.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  String _swipeLabel(String v) => switch (v) {
        'block' => '채널 차단만',
        'archive' => '아카이브만',
        _ => '차단 + 아카이브 선택',
      };

  Future<void> _pickSwipeAction(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('차단 + 아카이브'),
            trailing: _swipe == 'both' ? const Icon(Icons.check, color: IsleColors.ocean500) : null,
            onTap: () => Navigator.pop(ctx, 'both'),
          ),
          ListTile(
            title: const Text('채널 차단만'),
            trailing: _swipe == 'block' ? const Icon(Icons.check, color: IsleColors.ocean500) : null,
            onTap: () => Navigator.pop(ctx, 'block'),
          ),
          ListTile(
            title: const Text('아카이브만'),
            trailing: _swipe == 'archive' ? const Icon(Icons.check, color: IsleColors.ocean500) : null,
            onTap: () => Navigator.pop(ctx, 'archive'),
          ),
        ],
      ),
    );
    if (picked != null) {
      await IsleUserDefaults.setSwipeRightAction(picked);
      setState(() => _swipe = picked);
    }
  }
}
