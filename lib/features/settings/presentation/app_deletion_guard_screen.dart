import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/isle_app_bar.dart';

/// 앱 삭제 방지 안내.
///
/// **중요(07-09 정정, cage에서 먼저 발견)**: 예전엔 "앱을 지우면 차단이 풀린다"고
/// 안내했는데, 이건 사실과 반대일 가능성이 높다 — iOS의 `ManagedSettingsStore`
/// (개인용 Family Controls 인증)는 앱을 지워도 쉴드가 자동으로 안 풀리고,
/// 오히려 그 상태로 굳어버려서 Isle를 다시 설치해 직접 풀지 않는 한 손댈 방법이
/// 없어질 수 있다(Apple 개발자 문서·포럼에 반복적으로 보고된 동작 — Screen Time
/// 설정 UI에서도 안 보이는 앱 자체 관리 쉴드라 일반적인 "다운타임 끄기"로도 안
/// 풀림). 그래서 이 화면의 실제 의미는 "지우면 마찰 모델 구멍이 뚫린다"가 아니라
/// "지우기 전에 Isle 안에서 먼저 차단을 풀어야 한다, 지운 뒤엔 늦을 수 있다"임.
/// Screen Time 「앱 삭제 금지」는 실수로 지우는 걸 막는 안전장치로는 여전히 유효.
class AppDeletionGuardScreen extends StatelessWidget {
  const AppDeletionGuardScreen({super.key});

  static const _steps = <_GuardStep>[
    _GuardStep('설정 → 스크린 타임',
        '스크린 타임을 켜고, 「스크린 타임 [REDACTED] 암호를 정하세요. 이 암호는 본인만 알아야 효과가 있어요.'),
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
                    '⚠️ Isle를 지운다고 차단이 자동으로 풀리는 게 아니에요 — 오히려 '
                    '그 상태로 남아서 다시 설치해 직접 풀어야 할 수 있어요. 지우기 '
                    '전엔 반드시 Isle 안에서 먼저 차단을 해제하세요. 실수로 지우는 '
                    '걸 막으려면 Screen Time의 「앱 삭제 금지」를 켜 두세요.',
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
