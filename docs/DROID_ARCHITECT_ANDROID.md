# Droid Architect — Isle Android 변환 맵

## 프로토콜 요약

| 단계 | Isle 적용 |
|------|-----------|
| **Intent** | 사용자는 “앱 밖에서 유튜브 못 보게 + 앱 안 WebView만” |
| **Purge** | UI에서 Safari/Screen Time/iCloud를 Android 빌드에 노출하지 않음 (`PlatformBlockCopy`) |
| **Native map** | iOS 훅 제거·대체, Flutter 공통 로직 유지 |

## 기능 매핑

| iOS Mechanical Hook | Core Intent | Android Native |
|---------------------|-------------|----------------|
| `ManagedSettings` / Screen Time | OS·브라우저에서 youtube 차단 | 디지털 웰빙 · 앱 타이머, Chrome 사이트 설정, Private DNS |
| Safari Content Blocker extension | 동일 | **삭제** — `ContentBlocker.json` 등 불필요 |
| ASWebAuthenticationSession | Google 로그인 | `google_sign_in` + Custom Tabs (이미 Flutter) |
| iCloud / App Group | 백업·동기화 | 로컬 Hive + `Isle Backup` 폴더 / Drive (사용자 선택) |
| Share Extension | 링크 → 앱 | Android `ACTION_SEND` (`receive_sharing_intent`) |
| SF Symbols / iOS back chevron | — | Material Icons · 시스템 뒤로 (Flutter 기본) |

## 코드 위치 (Android 분기)

- `lib/core/platform/platform_block_intent.dart` — 플랫폼별 문구·라우트
- `lib/features/settings/presentation/android_system_block_screen.dart`
- `lib/features/youtube/presentation/widgets/android_system_block_sheet.dart`
- iOS 전용: `ios/Runner/ScreenTimeBridge.swift` (Android 빌드에 미포함)

## Phase 2 (미구현 — 의도만)

- `VpnService` + 로컬 DNS loopback (전 브라우저 youtube.com)
- `AccessibilityService` (타 앱 WebView 차단 — 정책·스토어 리스크)
- Android 14+ `WebContent` API (Chrome 한정)

## Flutter 공통 (양 플랫폼)

- WebView 유튜브 · 일일 한도 · 차단 스케줄 · 피드 · AI 기사화 · Feed Boost
