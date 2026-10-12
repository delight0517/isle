import 'package:flutter_test/flutter_test.dart';
import 'package:isle/features/explorer/presentation/web_explorer_screen.dart';

/// 2026-07-20 제보 "유튜브 시간 카운팅을 영상 재생 시간을 제대로 못 잡는 것
/// 같아" 재현/회귀 테스트.
///
/// `_onWatchTick`은 1초 `Timer.periodic`마다 WebView JS 브릿지 왕복
/// (`runJavaScriptReturningResult`)으로 "지금 재생 중인가"를 확인한다. 유튜브
/// 페이지가 무겁거나(광고·버퍼링) 기기가 느려 이 왕복이 1초보다 오래 걸리면,
/// 그 사이 다시 발화한 `Timer.periodic` 콜백은 재진입 가드(`_watchTickBusy`)에
/// 막혀 아무 것도 하지 않고 반환된다. 예전 코드는 "완료된 tick마다 무조건
/// +1초"만 적립했기 때문에, 스킵된 tick의 시간은 통째로 유실됐다 — 이게 실제
/// 재생 시간보다 카운트가 적게 잡히는 원인이었다.
///
/// `watchTickCreditSeconds`는 그 수정의 핵심 — 마지막 적립 시각부터 실제
/// 경과한 시간(clamp 적용)을 되돌려줘서, 중간에 몇 개의 tick이 스킵되든
/// 최종 적립 합계가 실제 시청 시간과 일치하게 한다.
void main() {
  group('watchTickCreditSeconds (순수 함수)', () {
    test('처음 호출(lastCreditAt == null)이면 1초만 적립', () {
      final now = DateTime(2026, 7, 20, 10, 0, 0);
      expect(
        watchTickCreditSeconds(lastCreditAt: null, now: now),
        1,
      );
    });

    test('정상적인 1초 tick — 정확히 1초 경과면 1초 적립', () {
      final last = DateTime(2026, 7, 20, 10, 0, 0);
      final now = last.add(const Duration(seconds: 1));
      expect(
        watchTickCreditSeconds(lastCreditAt: last, now: now),
        1,
      );
    });

    test(
        'JS 브릿지 왕복이 느려 tick이 2번 스킵된 경우(3초 경과) — '
        '스킵된 시간을 되돌려 3초 적립(예전엔 1초만 적립되던 유실 지점)', () {
      final last = DateTime(2026, 7, 20, 10, 0, 0);
      final now = last.add(const Duration(seconds: 3));
      expect(
        watchTickCreditSeconds(lastCreditAt: last, now: now),
        3,
      );
    });

    test('기기 프리즈·백그라운드처럼 비정상적으로 긴 공백은 상한(clamp)까지만 적립',
        () {
      final last = DateTime(2026, 7, 20, 10, 0, 0);
      final now = last.add(const Duration(minutes: 10));
      expect(
        watchTickCreditSeconds(lastCreditAt: last, now: now),
        5, // default maxCreditSeconds
      );
    });

    test('maxCreditSeconds를 조절하면 그 값까지만 적립', () {
      final last = DateTime(2026, 7, 20, 10, 0, 0);
      final now = last.add(const Duration(seconds: 30));
      expect(
        watchTickCreditSeconds(
          lastCreditAt: last,
          now: now,
          maxCreditSeconds: 8,
        ),
        8,
      );
    });

    test('시계가 거꾸로 가는 등 경과 시간이 0 이하이면 최소 1초는 적립', () {
      final last = DateTime(2026, 7, 20, 10, 0, 5);
      final now = DateTime(2026, 7, 20, 10, 0, 0); // now < last
      expect(
        watchTickCreditSeconds(lastCreditAt: last, now: now),
        1,
      );
    });

    test('여러 번의 스킵을 시뮬레이션 — 총 적립이 실제 경과 시간과 같아진다', () {
      // 실제 시청은 10초 동안 끊김없이 계속됐다고 가정. 그런데 JS 브릿지가
      // 느려서 tick이 [1,1,1,4,1,1,1]초 간격으로만 완료됐다고 하자(총 10초).
      final gaps = [1, 1, 1, 4, 1, 1, 1];
      var clock = DateTime(2026, 7, 20, 10, 0, 0);
      DateTime? lastCreditAt;
      var totalCredited = 0;
      for (final gapSeconds in gaps) {
        clock = clock.add(Duration(seconds: gapSeconds));
        final credited =
            watchTickCreditSeconds(lastCreditAt: lastCreditAt, now: clock);
        totalCredited += credited;
        lastCreditAt = clock;
      }
      expect(totalCredited, 10);
    });
  });
}
