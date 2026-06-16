# LATEST_CHANGES — 2026-06-05

## YouTube 검색 무한 버퍼링 수정

**원인**
- 검색·결과 URL도 `onPageStarted` → 로딩/자동복구 트리거
- 서브리소스 오류로 `reload()` 루프
- 결과 DOM 직전 차단 스크립트 주입이 SPA 로드와 충돌

**추가**
- `youtube_nav_policy.dart` — 시청 vs 탐색(검색·홈) URL 구분
- `test/youtube_nav_policy_test.dart`

**변경**
- `isle_playback_guard.dart` — 탐색면에서 로딩·HTTP/리소스 복구·DOM 재생 오탐 스킵
- `web_explorer_screen.dart` — 탐색면 스피너 숨김, inject 750~900ms 지연, 탐색 시 probe 생략

**버전:** 1.5.5+127
