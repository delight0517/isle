# iOS 앱별 시간 한도 (Device Activity)

## 필요 조건

- Paid Apple Developer Program (Family Controls)
- Runner: `Family Controls` + App Group `group.com.isle.app`
- **Device Activity Monitor Extension** (필수 — 한도 도달 시 자동 쉴드)

## 확장 추가 (Xcode)

1. File → New → Target → **Device Activity Monitor Extension**
2. Product name: `IsleDeviceActivityMonitor`
3. `ios/IsleDeviceActivityMonitor/IsleDeviceActivityMonitor.swift` 내용을 타깃에 연결 (또는 복사)
4. Extension entitlements: Family Controls + App Group `group.com.isle.app`
5. Extension `Info.plist`의 `NSExtensionPrincipalClass` 확인

## 동작

- Flutter `AppUsageLimitsScreen`에서 규칙 저장 → `registerLimit` → `DeviceActivityCenter.startMonitoring`
- 사용 시간이 `minutesPerDay`에 도달하면 확장의 `eventDidReachThreshold` → `ManagedSettingsStore` 쉴드
- 확장 없이 빌드하면 규칙 JSON만 저장되고 **자동 쉴드는 동작하지 않을 수 있음**

## 스케줄 경계 (차단 스케줄)

- 메인 앱이 슬롯마다 `DeviceActivityCenter.startMonitoring` 등록 (`IsleScheduleDeviceActivityBridge`)
- **확장 임베드 필수** — 앱이 완전히 종료된 뒤 경계에서 쉴드 갱신
- 가이드: [`IOS_EXTENSIONS_EMBED.md`](IOS_EXTENSIONS_EMBED.md)

## 테스트

1. 실기기에서 Screen Time 권한 승인
2. Instagram 등 **앱 1개만** 선택해 1~2분 한도로 테스트
3. 해당 앱 사용 후 시스템 쉴드 화면 표시 확인
