import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 앱 삭제 방지 안내.
///
/// 마찰 모델의 마지막 구멍(= Isle를 지워 쉴드를 무력화) 닫기. iOS는 서드파티가
/// 자기 삭제를 막을 수 없으므로, Screen Time 「앱 삭제 금지」를 사용자가 직접
/// 켜도록 단계별로 안내한다. 암호는 사용자가 정하고 Isle는 알 수 없다(§마찰 모델).
class AppDeletionGuardScreen extends StatelessWidget {
  const AppDeletionGuardScreen({super.key});

  static const _steps = <_GuardStep>[
    _GuardStep('설정 → 스크린 타임',
        '스크린 타임을 켜고, 「스크린 타임 암호 사용」으로 암호를 정하세요. 이 암호는 본인만 알아야 효과가 있어요.'),
    _GuardStep('콘텐츠 및 개인정보 보호 제한', '같은 화면에서 「콘텐츠 및 개인정보 보호 제한」을 켭니다.'),
    _GuardStep('iTunes 및 App Store 구입', '들어가서 「앱 삭제」를 「허용 안 함」으로 바꾸세요.'),
    _GuardStep('완료',
        '이제 홈 화면에서 Isle를 포함한 앱을 삭제할 수 없어요. 되돌리려면 스크린 타임 암호가 필요합니다.'),
  ];

  Future<void> _openSettings(BuildContext context) async {
    final uri = Uri.parse('app-settings:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정 → 스크린 타임에서 직접 켜 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IsleAppBar(title: '앱 삭제 방지'),
      body: ListView(
        padding: const EdgeInsets.all(IsleSize.screenPadding),
        children: [
          Card(
            color: IsleColors.ocean100,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('왜 필요한가요?', style: IsleText.subtitle()),
                  const SizedBox(height: 6),
                  Text(
                    'Isle 차단은 강력하지만, 앱을 지우면 풀려요. iOS는 앱이 스스로 '
                    '삭제를 막을 수 없어서, Screen Time의 「앱 삭제 금지」를 직접 켜야 '
                    '이 마지막 구멍이 닫힙니다.',
                    style: IsleText.body(color: IsleColors.ocean700).copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: IsleSize.cardGap),
          for (var i = 0; i < _steps.length; i++)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: IsleColors.ocean500,
                  foregroundColor: Colors.white,
                  child: Text('${i + 1}'),
                ),
                title: Text(_steps[i].title, style: IsleText.subtitle()),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _steps[i].detail,
                    style: IsleText.caption(color: IsleColors.muted).copyWith(height: 1.4),
                  ),
                ),
              ),
            ),
          const SizedBox(height: IsleSize.cardGap),
          SizedBox(
            height: IsleSize.minTouchTarget,
            child: FilledButton.icon(
              onPressed: () => _openSettings(context),
              icon: const Icon(Icons.settings),
              label: const Text('설정 열기'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '※ 스크린 타임 암호는 본인이 정하며 Isle는 알 수 없어요. '
            '암호를 잊으면 기기 초기화 전까지 해제할 수 없으니 신중히 정하세요.',
            style: IsleText.caption(color: IsleColors.danger).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _GuardStep {
  const _GuardStep(this.title, this.detail);
  final String title;
  final String detail;
}
