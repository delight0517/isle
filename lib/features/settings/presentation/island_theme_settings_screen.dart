import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/env.dart';
import '../../../core/island/island_theme_palette.dart';
import '../../../core/services/isle_user_defaults.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../auth/providers/auth_provider.dart';

/// 섬 테마 선택 — 로컬 저장 · Supabase 프로필 동기화(가능 시)
class IslandThemeSettingsScreen extends ConsumerStatefulWidget {
  const IslandThemeSettingsScreen({super.key});

  @override
  ConsumerState<IslandThemeSettingsScreen> createState() => _IslandThemeSettingsScreenState();
}

class _IslandThemeSettingsScreenState extends ConsumerState<IslandThemeSettingsScreen> {
  late String _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = IsleUserDefaults.islandThemeId;
  }

  Future<void> _pick(String id) async {
    setState(() {
      _selected = id;
      _saving = true;
    });
    await IsleUserDefaults.setIslandThemeId(id);
    if (Env.isSupabaseConfigured) {
      final profile = ref.read(currentUserProvider).value;
      if (profile != null) {
        try {
          await ref.read(authRepoProvider).updateProfile(profile.copyWith(islandTheme: id));
          ref.invalidate(currentUserProvider);
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${IslandThemePalette.byId(id).labelKo} 테마가 적용되었어요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IsleAppBar(title: '섬 테마'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '내 섬 3D 뷰의 하늘·잔디 색을 바꿉니다. 다른 사람 섬은 각자의 테마를 씁니다.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 16),
          ...IslandThemePalette.all.map((t) {
            final selected = t.id == _selected;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: selected ? IsleColors.ocean100 : Colors.white,
                borderRadius: BorderRadius.circular(IsleSize.cardRadius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(IsleSize.cardRadius),
                  onTap: _saving ? null : () => _pick(t.id),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        _ThemePreview(palette: t),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            t.labelKo,
                            style: IsleText.subtitle(
                              color: selected ? IsleColors.ocean900 : IsleColors.ocean700,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_circle, color: IsleColors.ocean700),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.palette});

  final IslandThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.skyTop, palette.skyBottom],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 18,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: palette.grassTop,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
