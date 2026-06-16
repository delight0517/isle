# Isle macOS — 차단·스케줄·브라우저

## Xcode

1. `isle/macos/Runner.xcworkspace` 열기
2. Runner → Signing: **Family Controls** + App Group `group.com.isle.app` (entitlements 포함)
3. macOS 13+ 실기기 권장 (Screen Time · DeviceActivity)

## 기능 (iOS와 동일 Dart)

| 기능 | 경로 |
|------|------|
| 차단 스케줄 | 설정 → 차단 스케줄 |
| 앱별 시간 한도 | 설정 → 앱별 시간 한도 |
| 다른 앱 즉시 차단 | 설정 → 다른 앱 즉시 차단 |
| Safari·Chrome 유튜브 | 설정 → 브라우저 유튜브 → Isle 트래킹 |
| Mac hosts보내기 | 차단 스케줄 → Mac hosts 파일 |

## Mac 전용

- **Screen Time**: `MacScreenTimeBridge` — 도메인·앱 쉴드 (macOS 14+ 웹)
- **앱 종료**: `MacAppBlockBridge` — 스케줄 활성 시 Instagram·TikTok 등 display name 종료 (6VPN Blocker 패턴)
- **브라우저 시간**: `MacBrowserSessionPlugin` — Safari·Chrome 전면 5초 tick

## 빌드

```bash
cd isle && flutter pub get && flutter run -d macos
```
