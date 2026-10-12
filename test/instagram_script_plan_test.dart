import 'package:flutter_test/flutter_test.dart';
import 'package:isle/core/explorer/isle_webview_factory.dart';

/// planInstagramScripts()는 실제 WebViewController 없이도 "어떤 스크립트가
/// 돌지"를 결정하는 순수 함수라 실기기/에뮬레이터 없이 모든 모드 조합을
/// 여기서 검증할 수 있다 (2026-07-12, "DM 집중 모드가 죽은 설정이던 버그"
/// 수정과 함께 도입 — 실기기 QA 없이도 회귀를 잡기 위함).
void main() {
  group('DM 모드', () {
    test('DM + 집중모드 ON → 포커스 스크립트만 돌고, 피드 전용 스크립트는 전부 꺼짐', () {
      final plan = planInstagramScripts(
        igPath: '/direct/inbox',
        instagramDmOnly: true,
        instagramMinimalScripts: false,
        dmFocusModeEnabled: true,
        hideReels: true,
        reelsGuardEnabled: true,
        exploreGuardEnabled: true,
      );
      expect(plan.isAuthFlow, false);
      expect(plan.minimalOnly, false);
      expect(plan.runDmFocusScript, true,
          reason: 'DM + 집중모드 ON이면 홈/탐색 차단 스크립트가 돌아야 함');
      expect(plan.runPostComments, false);
      expect(plan.runReelsHide, false,
          reason: '릴스 숨김은 피드 전용 — DM 웹뷰엔 절대 안 들어가야 함');
      expect(plan.runReelsGuard, false);
      expect(plan.runExploreGuard, false);
    });

    test('DM + 집중모드 OFF → 홈/탐색 차단 스크립트가 안 돌아야 함 (버그였던 지점)',
        () {
      final plan = planInstagramScripts(
        igPath: '/direct/inbox',
        instagramDmOnly: true,
        instagramMinimalScripts: false,
        dmFocusModeEnabled: false,
        hideReels: true,
        reelsGuardEnabled: true,
        exploreGuardEnabled: true,
      );
      expect(plan.runDmFocusScript, false,
          reason: '집중모드를 껐으면 이제 실제로 안 돌아야 한다 — 이게 예전엔 '
              '설정과 무관하게 항상 true였던 버그');
      // 집중모드를 껐다고 해서 피드 전용 스크립트가 DM 웹뷰에 새들어가면 안 됨 —
      // 그건 완전히 다른(더 나쁜) 버그가 된다.
      expect(plan.runPostComments, false);
      expect(plan.runReelsHide, false);
      expect(plan.runReelsGuard, false);
      expect(plan.runExploreGuard, false);
    });

    test('DM + 최소 스크립트 모드 → dmScrollPersistence만 돌고 즉시 종료', () {
      final plan = planInstagramScripts(
        igPath: '/direct/inbox',
        instagramDmOnly: true,
        instagramMinimalScripts: true,
        dmFocusModeEnabled: true,
        hideReels: true,
        reelsGuardEnabled: true,
        exploreGuardEnabled: true,
      );
      expect(plan.minimalOnly, true);
      expect(plan.runDmScrollPersistence, true);
      expect(plan.runDmFocusScript, false);
      expect(plan.runReelsHide, false);
    });
  });

  group('피드/탐색 모드', () {
    test('피드 모드 → 댓글 스크립트·릴스 숨김·릴스 가드는 설정대로, DM 포커스는 항상 꺼짐',
        () {
      final plan = planInstagramScripts(
        igPath: '/',
        instagramDmOnly: false,
        instagramMinimalScripts: false,
        dmFocusModeEnabled: true,
        hideReels: true,
        reelsGuardEnabled: true,
        exploreGuardEnabled: true,
      );
      expect(plan.runDmFocusScript, false,
          reason: '피드 모드에서는 dmFocusModeEnabled가 true여도 절대 돌면 안 됨');
      expect(plan.runPostComments, true);
      expect(plan.runReelsHide, true);
      expect(plan.runReelsGuard, true);
    });

    test('릴스 숨김/가드 설정이 꺼져 있으면 피드 모드에서도 안 돎', () {
      final plan = planInstagramScripts(
        igPath: '/',
        instagramDmOnly: false,
        instagramMinimalScripts: false,
        dmFocusModeEnabled: true,
        hideReels: false,
        reelsGuardEnabled: false,
        exploreGuardEnabled: true,
      );
      expect(plan.runReelsHide, false);
      expect(plan.runReelsGuard, false);
    });

    test('탐색(/explore) 경로 + 탐색 가드 설정 ON → 탐색 가드만 돎', () {
      final plan = planInstagramScripts(
        igPath: '/explore/',
        instagramDmOnly: false,
        instagramMinimalScripts: false,
        dmFocusModeEnabled: false,
        hideReels: false,
        reelsGuardEnabled: false,
        exploreGuardEnabled: true,
      );
      expect(plan.runExploreGuard, true);
    });

    test('홈 피드(비-탐색 경로)에서는 탐색 가드 설정이 켜져 있어도 안 돎', () {
      final plan = planInstagramScripts(
        igPath: '/',
        instagramDmOnly: false,
        instagramMinimalScripts: false,
        dmFocusModeEnabled: false,
        hideReels: false,
        reelsGuardEnabled: false,
        exploreGuardEnabled: true,
      );
      expect(plan.runExploreGuard, false,
          reason: '탐색 가드는 /explore 경로 전용이어야 함 — 홈 피드에서 잘못 도는 건 별개 버그');
    });
  });

  group('인증 흐름', () {
    test('로그인/인증 경로면 DM·피드 여부와 상관없이 아무 스크립트도 안 돎', () {
      final plan = planInstagramScripts(
        igPath: '/accounts/login/',
        instagramDmOnly: false,
        instagramMinimalScripts: false,
        dmFocusModeEnabled: true,
        hideReels: true,
        reelsGuardEnabled: true,
        exploreGuardEnabled: true,
      );
      expect(plan.isAuthFlow, true);
      expect(plan.runDmFocusScript, false);
      expect(plan.runPostComments, false);
      expect(plan.runReelsHide, false);
      expect(plan.runExploreGuard, false);
    });
  });
}
