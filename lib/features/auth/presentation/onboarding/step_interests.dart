import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/isle_user_defaults.dart';

class StepInterests extends StatefulWidget {
  const StepInterests({super.key});

  @override
  State<StepInterests> createState() => StepInterestsState();
}

class StepInterestsState extends State<StepInterests> {
  static const _tags = [
    '기술/IT',
    '재무/투자',
    '디자인',
    '철학/인문',
    '자기계발',
    '라이프스타일',
    '음악',
    '영화',
  ];

  final _selected = <String>{};

  List<String> get selectedTags => _selected.toList();

  @override
  void initState() {
    super.initState();
    _selected.addAll(IsleUserDefaults.onboardingInterestTags);
  }

  void _toggle(String tag) {
    setState(() {
      if (_selected.contains(tag)) {
        _selected.remove(tag);
      } else {
        _selected.add(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('관심 주제를\n골라 주세요', style: IsleText.title(color: IsleColors.ocean900)),
          const SizedBox(height: 8),
          Text(
            '3개 이상 고르면 피드·추천에 반영돼요. 설정에서 언제든 바꿀 수 있어요.',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((t) {
              final on = _selected.contains(t);
              return FilterChip(
                label: Text(t, style: IsleText.caption(color: on ? Colors.white : IsleColors.ocean900)),
                selected: on,
                onSelected: (_) => _toggle(t),
                selectedColor: IsleColors.ocean500,
                backgroundColor: IsleColors.ocean100,
                checkmarkColor: Colors.white,
              );
            }).toList(),
          ),
          const Spacer(),
          if (_selected.length < 3)
            Text('${_selected.length}/3개 선택됨', style: IsleText.caption(color: IsleColors.muted))
          else
            Row(
              children: [
                const Icon(Icons.check_circle, color: IsleColors.success, size: 20),
                const SizedBox(width: 8),
                Text('좋아요! 피드가 더 정확해져요', style: IsleText.caption(color: IsleColors.success)),
              ],
            ),
        ],
      ),
    );
  }
}
