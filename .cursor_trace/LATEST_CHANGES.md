# LATEST_CHANGES — 2026-07-03

## 사용 시간 리포트·판단 로그

**원인**
- 기존 플랫폼 사용 시간 화면은 총량 막대만 보여 주고, 왜 그런 판단을 했는지 복사 가능한 로그가 없었음.
- “많이 쓰는 시간대”는 기존 일별 버킷만으로는 복원할 수 없어 앞으로 쌓을 시간대 버킷이 필요했음.

**변경**
- `engagement_tracker.dart` — `hourly_seconds_v1` 버킷 추가. `recordScreen()` 호출 시 일별+시간대별 누적.
- `platform_usage_stats.dart` — 평균, 활성일 평균, 최다 플랫폼, 최다 사용일, 최다 시간대, 판단 이유를 포함한 `PlatformUsageReport` 추가.
- `platform_usage_stats_screen.dart` — 사용 패턴 리포트 카드 추가. 평균/많이 쓴 서비스/많은 시간대 표시, 상세 펼치기, 리포트 로그 복사 지원.

**검증**
- `dart format` 대상 파일 통과.
- `flutter analyze --no-fatal-infos lib/core/library/engagement_tracker.dart lib/core/library/platform_usage_stats.dart lib/features/settings/presentation/platform_usage_stats_screen.dart` 통과.

**버전:** 1.6.0+312

---

## Safari 홈 복귀 UX

**원인**
- custom Safari 화면은 `PopScope(canPop: false)`에서 WebView 히스토리를 우선 소비해 iOS 기본 edge-swipe pop이 동작하지 않았음.
- 상단 왼쪽 화살표도 브라우저 뒤로가기로 연결되어, 사용자가 앱 홈으로 빠져나갈 명확한 경로가 부족했음.

**변경**
- `web_explorer_screen.dart` — custom Safari 상단 왼쪽 버튼을 앱 홈(`/home/sns`) 이동으로 분리.
- custom Safari 왼쪽 edge swipe 영역 추가: 화면 왼쪽 모서리에서 오른쪽으로 스와이프하면 앱 홈으로 이동.
- Safari 메뉴에 `홈으로 나가기` 항목 추가.
- 하단 브라우저 바의 왼쪽 화살표는 기존대로 WebView 뒤로가기로 유지.

**검증**
- `dart format` 대상 파일 통과.
- `flutter analyze --no-fatal-infos lib/features/explorer/presentation/web_explorer_screen.dart lib/core/constants/app_release_info.dart` 통과(기존 info lint만 존재).

**버전:** 1.6.0+310

---

# LATEST_CHANGES — 2026-07-01

## 브라우저 렉 최적화 2차

**원인**
- Google 검색/URL 차단 JS의 `MutationObserver`가 검색 결과 변화 때마다 즉시 전체 sweep을 예약할 수 있었음.
- Instagram DM 경로 저장 스크립트가 400ms polling으로 URL 변화를 확인했음.
- Instagram 미디어 viewer 보정 스크립트가 viewer가 닫혀 있어도 900ms 고정 주기로 video sweep을 반복했음.

**변경**
- `google_search_keyword_block_script.dart` — observer callback을 180ms debounce + `requestAnimationFrame`으로 병합.
- `google_surface_url_block_script.dart` — URL 표면 차단 sweep도 동일하게 debounce.
- `instagram_dm_navigation_script.dart` — `history.pushState`/`replaceState`/`popstate` hook 우선, fallback polling은 1200ms로 완화.
- `instagram_media_viewer_script.dart` — viewer 열림 상태 700ms, 닫힘 상태 1600ms adaptive polling으로 변경.

**검증**
- `flutter analyze --no-fatal-infos` 대상 파일 통과.
- `flutter test test/google_search_keyword_block_test.dart test/blocked_url_guard_test.dart test/instagram_auth_path_policy_test.dart test/instagram_dm_path_policy_test.dart test/instagram_safari_launch_guard_test.dart` 통과.

**리스크 / 확인 필요**
- 차단 조건·preview 차단·로그인/DM 정책은 유지. 실기기에서 Google 검색 결과 숨김과 Instagram DM URL 추적만 수동 확인 필요.
- `v1.6.0+305` iOS Profile `Runner.app` 빌드는 성공. 설치는 `CoreDeviceService was unable to locate a device` / iPhone `unavailable` 상태로 대기.

**버전:** 1.6.0+305

---

## 브라우저 렉 최적화 1차

**원인**
- 정상 시청 중에도 재생 차단 JS가 150ms interval을 설치할 수 있었음.
- WebView 사용 시간 tick이 1초마다 전체 `WebExplorerScreen`을 rebuild하고, 일부 시간 저장소 write도 초 단위로 발생.
- YouTube/custom 브라우저 차단 스크립트 fallback sweep 주기가 짧아 홈·검색·일반 웹페이지에서 DOM 스캔 비용이 누적.

**변경**
- `youtube_webview_energy.dart` — `blocked=false`면 enforcement interval clear, `blocked=true`일 때만 150ms 루프 유지.
- `web_explorer_screen.dart` — 시간 UI를 `ValueNotifier`로 분리해 전체 화면 1초 rebuild 제거, 사용시간·스케줄 사용량을 5초 batch flush.
- `youtube_channel_block_script.dart` — preview/play/event guard는 유지하고 fallback sweep 주기 완화, 중복 video sweep 제거.
- `youtube_embed_surface_guard_script.dart` — custom Safari embed fallback polling을 300ms에서 조건부 900/2200ms로 완화.
- `youtube_channel_block_guard_test.dart` — light-mode sweep 기대값을 새 성능 정책에 맞춰 갱신.

**검증**
- `flutter analyze --no-fatal-infos` 대상 파일 통과(기존 info lint만 존재).
- `flutter test test/youtube_channel_block_guard_test.dart test/youtube_block_bypass_guard_test.dart test/youtube_safari_launch_guard_test.dart` 통과.

**리스크 / 확인 필요**
- 실기기에서 YouTube 홈·검색 preview 차단 유지, 한도 도달 후 재생 정지, custom Safari embed 차단을 확인할 것.
- `v1.6.0+304` iOS Profile `Runner.app` 빌드는 성공. 설치는 `CoreDeviceService was unable to locate a device` / iPhone `unavailable` 상태로 대기.

**버전:** 1.6.0+304

---

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
# LATEST_CHANGES — 2026-10-12

## 배포 후보 최신 기준 정렬 및 버전 갱신

- 로컬 `main`을 원격 최신 `d8f6d36`까지 fast-forward했다. 원격 선행 변경은 README 개발자 소개뿐이며 앱 소스와 충돌하지 않았다.
- 모든 기존 사용자 변경은 보존하고 검토용 브랜치 `codex/moa-safe-deploy-20261012`에서 검증을 준비한다.
- 사용자 가시 앱 변경 릴리스 후보이므로 `AppReleaseInfo`와 `pubspec.yaml` 버전을 `1.6.0+380`으로 맞췄다. 이전 iPhone 설치 기록은 build 379다.
- 자동 Watch Later/계정 시청 기록 수집은 YouTube Data API 제한으로 지원 불가를 표시하고, MOA 인앱 재생 기록과 지원되는 동기화 범위를 구분한다.

**검증:** `dart analyze` 컴파일 오류 0 (기존 경고/정보 lint는 남음), `flutter test` 713/713 통과, iOS Release `--no-codesign` 빌드 통과, Android Full Release AAB 빌드 및 서명 검증 통과.
**실기기:** iPhone 사용 가능 상태는 보고되었지만 최신 후보는 아직 설치되지 않았다. Screen Time/Instagram 복원 여정은 미검증 상태로 유지한다.
**배포 경계:** Mac에서 `main`에 직접 push/배포하지 않으며, 검증 후 review PR 경로를 사용한다.

---

## 보안 배포 게이트 — 개발 API 키 자동 주입 제거

- 개발 bootstrap의 하드코딩 provider key 자동 저장을 비활성화했다. 앱은 사용자가 보안 설정에서 입력한 키만 사용한다.
- 키 제거 뒤 전체 테스트 713/713, iOS Release 무서명 앱 재빌드, Android Full Release AAB 재빌드와 custom(비-debug) 인증서 서명 검증을 통과했다. 새 iOS 번들에서는 AI provider key 패턴 0건이다.
- AAB의 `google_api_key`는 Firebase 공개 클라이언트 설정이며 포함이 예상된다. 실제 Google Cloud API 제한 상태는 확인되지 않아 배포 게이트로 남긴다.
- 과거 포함됐던 AI provider key의 발급처 폐기·교체가 필요하다. 이와 실기기 확인 전에는 PR을 draft로만 검토하고 스토어 배포하지 않는다.
