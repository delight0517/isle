import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/env.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../core/services/setup_journey_service.dart';
import '../../../core/utils/topic_matcher.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../feed/providers/feed_provider.dart';
import '../providers/settings_provider.dart';

class InterestsEditScreen extends ConsumerStatefulWidget {
  const InterestsEditScreen({super.key});

  @override
  ConsumerState<InterestsEditScreen> createState() => _InterestsEditScreenState();
}

class _InterestsEditScreenState extends ConsumerState<InterestsEditScreen> {
  final Set<String> _selected = {};
  bool _hydrated = false;

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(userInterestTagsProvider);

    return Scaffold(
      appBar: const IsleAppBar(title: '관심사 편집'),
      body: tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (remote) {
          if (!_hydrated) {
            _hydrated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selected.addAll(remote));
            });
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('관심 태그', style: IsleText.subtitle()),
              const SizedBox(height: 8),
              Text(
                Env.isSupabaseConfigured
                    ? '선택한 태그가 피드·추천 매칭에 반영됩니다. 기기에도 저장됩니다.'
                    : '지금은 기기에 저장되며, 피드 순위에 바로 반영됩니다.',
                style: IsleText.caption(color: IsleColors.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TopicMatcher.presetInterestTags.map((t) {
                  final on = _selected.contains(t);
                  return FilterChip(
                    label: Text(t, style: IsleText.caption()),
                    selected: on,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selected.add(t);
                      } else {
                        _selected.remove(t);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => _save(context),
                  style: FilledButton.styleFrom(backgroundColor: IsleColors.ocean500),
                  child: Text('저장', style: IsleText.subtitle(color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final tags = _selected.toList();
    await IsleUserDefaults.setOnboardingInterestTags(tags);
    await SetupJourneyService.markStepDone('interests');

    final user = ref.read(authStateProvider).value;
    if (user != null && Env.isSupabaseConfigured) {
      try {
        await ref.read(settingsRepoProvider).replaceInterestTags(user.id, tags);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('서버 저장 실패 · 기기에는 저장됨: $e')),
          );
        }
      }
    }

    ref.invalidate(userInterestTagsProvider);
    ref.invalidate(feedProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관심사를 저장했습니다. 피드를 새로고침해 보세요.')),
      );
    }
  }
}
