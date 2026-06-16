# iOS 확장 타깃 임베드 (Device Activity + Safari)

Runner 앱만으로는 **앱이 꺼진 뒤** 스케줄 경계·Safari 차단이 자동으로 안 될 수 있어요.

## 자동 임베드 (권장)

```bash
cd isle/ios
gem install xcodeproj   # 최초 1회
ruby embed_isle_extensions.rb
```

이후 Xcode에서 **Runner** 스킴으로 실기기 빌드.  
앱 **설정 → iPhone 차단 기능** 진단 카드에서 `Device Activity 확장` / `Safari Content Blocker` 가 **임베드됨**이면 성공.

## 수동 (Xcode UI)

### 1. Device Activity Monitor (`IsleDeviceActivityMonitor`)

1. Xcode → File → New → Target → **Device Activity Monitor Extension**
2. Product name: `IsleDeviceActivityMonitor`
3. 기존 파일 사용:
   - `ios/IsleDeviceActivityMonitor/IsleDeviceActivityMonitor.swift`
   - `ios/IsleDeviceActivityMonitor/Info.plist`
   - `ios/IsleDeviceActivityMonitor/IsleDeviceActivityMonitor.entitlements`
4. Capabilities: **Family Controls** + App Group `group.com.isle.app`
5. Bundle ID 예: `com.isle.app.isle.dev.dfbeta22.IsleDeviceActivityMonitor`

**동작:** 메인 앱이 `syncScheduleDeviceActivities`로 슬롯별 모니터 등록 → 확장 `intervalDidStart/End`에서 `schedule_snapshot_v1.json` 기준 쉴드 재적용.

## 2. Safari Content Blocker (`IsleSafariContentBlocker`)

1. File → New → Target → **Content Blocker Extension**
2. Product name: `IsleSafariContentBlocker`
3. 파일:
   - `ios/IsleSafariContentBlocker/ContentBlockerRequestHandler.swift`
   - `ios/IsleSafariContentBlocker/blockerList.json` (폴백)
   - `ios/IsleSafariContentBlocker/Info.plist`
   - `ios/IsleSafariContentBlocker/IsleSafariContentBlocker.entitlements`
4. App Group `group.com.isle.app` (메인과 동일)
5. iPhone **설정 → Safari → 확장 프로그램**에서 Isle 차단 켜기

**동작:** Isle가 `content_blocker_v1.json`을 App Group에 씀 → 확장이 Safari에 규칙 전달 (`rules_v1.json`과 별도).

## 메인 앱 (이미 포함)

- `IsleScheduleDeviceActivityBridge.swift` — 슬롯 모니터 등록
- `ScheduleSyncRunner` — BGTask `com.isle.app.scheduleSync`
- 스케줄 동기화 시 `IosScheduleDeviceActivityService` + `IosRulesExportService` 자동 호출

## 테스트

1. 실기기 · Screen Time 승인
2. 스케줄 1개 · 2분 뒤 시작 슬롯
3. 앱 종료 후 슬롯 시작 시각에 Instagram 쉴드(확장 임베드 후)
4. Safari에서 youtube.com — Content Blocker ON 후 차단 확인
