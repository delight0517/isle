import Flutter
import Security
import SwiftUI
import UIKit
import WebKit

#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
#endif

private enum IsleAppGroupFiles {
  static let appGroupId = IsleAppIdentity.appGroupId

  static var containerURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
  }

  @discardableResult
  static func writeFile(name: String, content: String) -> Bool {
    guard let dir = containerURL else { return false }
    let url = dir.appendingPathComponent(name)
    do {
      try content.write(to: url, atomically: true, encoding: .utf8)
      return true
    } catch {
      return false
    }
  }

  static func appGroupPath() -> String? {
    containerURL?.path
  }
}

private enum IsleScreenTimeStores {
  #if canImport(ManagedSettings)
  static let schedule = ManagedSettingsStore(named: .init("IsleSchedule"))
  static let manualWeb = ManagedSettingsStore(named: .init("IsleManualWeb"))
  #endif
}

// MARK: - FamilyActivityPicker (Focusgate 패턴)

#if canImport(FamilyControls)
private struct IsleFamilyPickerContainer: View {
  @State private var selection: FamilyActivitySelection
  let onFinish: (FamilyActivitySelection) -> Void
  let onCancel: () -> Void
  let title: String

  init(
    initial: FamilyActivitySelection,
    title: String = "차단할 앱·카테고리",
    onFinish: @escaping (FamilyActivitySelection) -> Void,
    onCancel: @escaping () -> Void
  ) {
    _selection = State(initialValue: initial)
    self.onFinish = onFinish
    self.onCancel = onCancel
    self.title = title
  }

  var body: some View {
    NavigationStack {
      FamilyActivityPicker(selection: $selection)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("취소") { onCancel() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("완료") { onFinish(selection) }
          }
        }
    }
  }
}

extension UIViewController {
  static func isleTopMost() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    guard let scene = scenes.first(where: {
      $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive
    }) ?? scenes.first else { return nil }
    let window = scene.windows.first { $0.isKeyWindow } ?? scene.windows.first
    guard var top = window?.rootViewController else { return nil }
    while let presented = top.presentedViewController { top = presented }
    if let nav = top as? UINavigationController { top = nav.visibleViewController ?? nav }
    if let tab = top as? UITabBarController { top = tab.selectedViewController ?? tab }
    return top
  }
}

enum IsleFamilyActivityPickerUI {
  @MainActor
  static func present(
    existingEncoded: String?,
    additiveOnly: Bool = false,
    title: String = "차단할 앱·카테고리",
    completion: @escaping (Result<[String: Any], Error>) -> Void
  ) {
    var initial = FamilyActivitySelection()
    if let existingEncoded,
       let data = Data(base64Encoded: existingEncoded),
       let decoded = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
      initial = decoded
    }

    guard let presenter = UIViewController.isleTopMost() else {
      completion(.failure(NSError(domain: "IsleScreenTime", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "화면을 찾을 수 없습니다.",
      ])))
      return
    }

    var hostingRef: UIHostingController<IsleFamilyPickerContainer>!
    hostingRef = UIHostingController(
      rootView: IsleFamilyPickerContainer(
        initial: initial,
        title: title,
        onFinish: { selection in
          hostingRef.dismiss(animated: true) {
            do {
              let finalSel: FamilyActivitySelection
              if additiveOnly {
                var merged = initial
                merged.applicationTokens.formUnion(selection.applicationTokens)
                merged.categoryTokens.formUnion(selection.categoryTokens)
                merged.webDomainTokens.formUnion(selection.webDomainTokens)
                finalSel = merged
              } else {
                finalSel = selection
              }
              let data = try PropertyListEncoder().encode(finalSel)
              completion(.success([
                "encoded": data.base64EncodedString(),
                "applicationCount": finalSel.applicationTokens.count,
                "categoryCount": finalSel.categoryTokens.count,
                "webDomainCount": finalSel.webDomainTokens.count,
              ]))
            } catch {
              completion(.failure(error))
            }
          }
        },
        onCancel: {
          hostingRef.dismiss(animated: true) {
            completion(.failure(NSError(domain: "IsleScreenTime", code: 2, userInfo: [
              NSLocalizedDescriptionKey: "cancelled",
            ])))
          }
        }
      )
    )
    hostingRef.modalPresentationStyle = .fullScreen
    presenter.present(hostingRef, animated: true)
  }
}
#endif

// MARK: - Bridge

/// Screen Time — 앱 쉴드 + 웹 도메인 (4vpnBlocker·Focusgate 패턴)
@available(iOS 16.0, *)
final class ScreenTimeBridge: NSObject {
  func hasFamilyControlsEntitlement() -> Bool {
    // SecTaskCreateFromSelf / SecTaskCopyValueForEntitlement are macOS-only APIs
    // and are not available on iOS. On iOS the entitlement is enforced by the
    // provisioning profile at install time, so a runtime check is not needed.
    // Return true and let FamilyControls.requestAuthorization handle actual access.
    return true
  }

  func isAvailable() -> Bool {
    #if canImport(FamilyControls)
    return true
    #else
    return false
    #endif
  }

  /// 단순 bool 버전 — 기존 호출부 호환용. 신규 코드는 `requestAuthorizationDetailed` 권장.
  func requestAuthorization(completion: @escaping (Bool) -> Void) {
    requestAuthorizationDetailed { dict in
      completion((dict["ok"] as? Bool) == true)
    }
  }

  /// 실패 사유까지 돌려주는 버전 — UI가 시뮬레이터/iCloud 미로그인/거부 등을 구분해 안내할 수 있게.
  /// 반환 키: ok(Bool), status(String), code(String?), message(String?)
  func requestAuthorizationDetailed(completion: @escaping ([String: Any]) -> Void) {
    #if targetEnvironment(simulator)
    completion([
      "ok": false,
      "status": ScreenTimeBridge.authorizationStatusString(),
      "code": "simulator",
      "message": "iOS 시뮬레이터에서는 Screen Time 다이얼로그가 뜨지 않아요. 실제 iPhone에서 다시 시도해 주세요.",
    ])
    return
    #else
    #if canImport(FamilyControls)
    Task { @MainActor in
      await Self.waitForActiveSceneIfNeeded()
      let result = await Self.requestAuthorizationWithRetry()
      completion(result)
    }
    #else
    completion([
      "ok": false,
      "status": "unavailable",
      "code": "unavailable",
      "message": "이 빌드에 FamilyControls 모듈이 포함돼 있지 않아요.",
    ])
    #endif
    #endif
  }

  @MainActor
  private static func waitForActiveSceneIfNeeded() async {
    for _ in 0..<8 {
      if UIApplication.shared.applicationState == .active { return }
      try? await Task.sleep(nanoseconds: 150_000_000)
    }
  }

  @MainActor
  private static func requestAuthorizationWithRetry() async -> [String: Any] {
    // 이미 승인됐으면 OS 호출 없이 즉시 반환 — 업데이트 후 불필요한 다이얼로그 방지.
    if AuthorizationCenter.shared.authorizationStatus == .approved {
      return ["ok": true, "status": "approved"]
    }

    // 4099(XPC helper race) 완화: 짧은 backoff로 최대 3회 시도.
    let retryDelaysNs: [UInt64] = [0, 450_000_000, 1_200_000_000]
    var lastError: Error?

    for (index, delay) in retryDelaysNs.enumerated() {
      if delay > 0 {
        try? await Task.sleep(nanoseconds: delay)
      }
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        let approved = AuthorizationCenter.shared.authorizationStatus == .approved
        return [
          "ok": approved,
          "status": ScreenTimeBridge.authorizationStatusString(),
        ]
      } catch {
        lastError = error
        let (code, message) = ScreenTimeBridge.classifyAuthError(error)
        let isLast = index == retryDelaysNs.count - 1
        if code != "error_4099" || isLast {
          return [
            "ok": false,
            "status": ScreenTimeBridge.authorizationStatusString(),
            "code": code,
            "message": message,
          ]
        }
      }
    }

    let (code, message) = ScreenTimeBridge.classifyAuthError(
      lastError ?? NSError(domain: "IsleScreenTime", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "알 수 없는 Screen Time 오류",
      ])
    )
    return [
      "ok": false,
      "status": ScreenTimeBridge.authorizationStatusString(),
      "code": code,
      "message": message,
    ]
  }

  /// FamilyControlsError + 일반 NSError를 사람 읽을 수 있는 사유로 변환.
  static func classifyAuthError(_ error: Error) -> (String, String) {
    #if canImport(FamilyControls)
    if let fcError = error as? FamilyControlsError {
      switch fcError {
      case .authorizationCanceled:
        return ("canceled", "권한 요청이 취소됐어요. 다시 시도해 주세요.")
      case .authorizationConflict:
        return ("conflict", "다른 Screen Time 앱과 충돌이 있어요. 기존 차단 앱의 권한을 해제한 뒤 다시 시도해 주세요.")
      case .invalidAccountType:
        return ("invalidAccountType", "이 Apple 계정으로는 Screen Time을 쓸 수 없어요. iCloud에 로그인되어 있는지 확인해 주세요.")
      case .networkError:
        return ("network", "네트워크 오류로 권한 요청에 실패했어요. Wi-Fi/셀룰러 연결을 확인해 주세요.")
      case .restricted:
        return ("restricted", "이 기기에 부모님이 설정한 제한이 있어요. 설정 → 스크린 타임에서 제한을 해제해 주세요.")
      case .unavailable:
        return ("unavailable", "이 기기·iOS 버전에서는 Screen Time을 쓸 수 없어요. iOS 16 이상이 필요합니다.")
      @unknown default:
        return ("familyControlsUnknown", "Screen Time 권한 요청에 실패했어요: \(error.localizedDescription)")
      }
    }
    #endif
    let ns = error as NSError
    if ns.code == 4099 {
      return (
        "error_4099",
        "Screen Time 시스템 helper와 통신이 잠시 끊겼어요. 잠시 후 다시 시도하거나 설정 앱을 한 번 열고 돌아와 주세요."
      )
    }
    return ("error_\(ns.code)", ns.localizedDescription)
  }

  static func authorizationStatusString() -> String {
    #if canImport(FamilyControls)
    switch AuthorizationCenter.shared.authorizationStatus {
    case .notDetermined: return "notDetermined"
    case .denied: return "denied"
    case .approved: return "approved"
    @unknown default: return "notDetermined"
    }
    #else
    return "unavailable"
    #endif
  }

  func isAuthorized() -> Bool {
    #if canImport(FamilyControls)
    return AuthorizationCenter.shared.authorizationStatus == .approved
    #else
    return false
    #endif
  }

  /// 스케줄 도메인 — OS `webContent`에는 적용하지 않음 (Isle WebView까지 차단됨).
  /// youtube.com처럼 Safari 안 특정 사이트만 막고 싶으면 여기가 아니라
  /// `applyAppShield`의 `store.shield.webDomains`(FamilyActivityPicker "웹 사이트"
  /// 탭에서 고른 도메인)를 쓴다 — Safari 전용 인터스티셜 쉴드라 콘텐츠 필터
  /// 익스텐션을 안 거치고, Isle WKWebView의 googlevideo.com 스트림과 안 겹친다
  /// (2026-[REDACTED] 조사 완료 — TODO.md 참고, 이 함수는 그 목적으로 안 씀).
  func applyScheduleWebDomains(domains: [String]) -> Bool {
    #if canImport(FamilyControls) && canImport(ManagedSettings)
    guard AuthorizationCenter.shared.authorizationStatus == .approved else { return false }
    if #available(iOS 17.0, *) {
      IsleScreenTimeStores.schedule.webContent.blockedByFilter = nil
      return true
    }
    #endif
    return false
  }

  func applyAppShield(encoded: String) -> Bool {
    #if canImport(FamilyControls) && canImport(ManagedSettings)
    guard AuthorizationCenter.shared.authorizationStatus == .approved,
          let data = Data(base64Encoded: encoded),
          let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    else { return false }

    let store = IsleScreenTimeStores.schedule
    if selection.applicationTokens.isEmpty {
      store.shield.applications = nil
    } else {
      store.shield.applications = selection.applicationTokens
    }
    if selection.categoryTokens.isEmpty {
      store.shield.applicationCategories = nil
    } else {
      store.shield.applicationCategories = .specific(selection.categoryTokens, except: Set())
    }
    if selection.webDomainTokens.isEmpty {
      store.shield.webDomains = nil
    } else {
      // ManagedSettings: webDomains is Set<WebDomainToken>?, not .specific policy.
      store.shield.webDomains = selection.webDomainTokens
    }
    return true
    #else
    return false
    #endif
  }

  /// "올나이트 록다운" — 설치된 앱 전체를 카테고리 단위로 쉴드한다. 개별 앱
  /// 선택(`applyAppShield`가 쓰는 `shield.applications`)과는 별개 키
  /// (`shield.applicationCategories`)라 서로 덮어쓰지 않고 같이 적용된다.
  /// 전화·긴급 SOS는 OS가 ManagedSettings 쉴드 대상에서 항상 제외하므로
  /// 여기서 따로 예외 처리할 필요가 없다(Apple 시스템 보호 앱).
  func applyLockdownShield(enable: Bool, allowedAppsEncoded: String?) -> Bool {
    #if canImport(FamilyControls) && canImport(ManagedSettings)
    guard AuthorizationCenter.shared.authorizationStatus == .approved else { return false }
    let store = IsleScreenTimeStores.schedule
    if enable {
      let allowed = allowedAppsEncoded
        .flatMap { Data(base64Encoded: $0) }
        .flatMap { try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: $0) }
      IsleScheduleShieldSync.saveLockdownAllowedSelection(allowedAppsEncoded)
      store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.all(
        except: allowed?.applicationTokens ?? Set()
      )
    } else {
      store.shield.applicationCategories = nil
    }
    return true
    #else
    return false
    #endif
  }

  func clearScheduleEnforcement() {
    #if canImport(ManagedSettings)
    IsleScreenTimeStores.schedule.clearAllSettings()
    #endif
  }

  /// 레거시 — 스케줄 도메인만 적용
  func applyShield(domains: [String]) {
    _ = applyScheduleWebDomains(domains: domains)
  }

  func stopShield() {
    clearScheduleEnforcement()
  }

  /// Deprecated — OS 도메인 차단은 Isle WebView까지 막음. 해제만 수행하고 `false` 반환.
  func applyYoutubeWebDomainBlock() -> Bool {
    clearAllWebContentFilters()
    return false
  }

  func clearWebContentBlock() {
    clearAllWebContentFilters()
  }

  /// 예전 버전이 남긴 OS web content/도메인 차단 전체 해제 (Isle WKWebView 재생 복구).
  ///
  /// 「try again later / Playback ID」 오류의 실제 원인: 과거 버전이 ManagedSettings에
  /// youtube.com web content 필터 또는 web 도메인 쉴드를 걸어두면, OS가 Isle 인앱
  /// WKWebView의 미디어 스트림(googlevideo.com)까지 막아 페이지는 뜨지만 재생만 실패한다.
  /// 업데이트해도 ManagedSettings는 영구 보존되므로 명시적으로 모든 스토어를 비워야 한다.
  func clearAllWebContentFilters() {
    #if canImport(ManagedSettings)
    // 현재·레거시 named 스토어 + 과거 버전이 썼을 수 있는 기본(unnamed) 스토어 모두.
    let stores: [ManagedSettingsStore] = [
      IsleScreenTimeStores.manualWeb,
      IsleScreenTimeStores.schedule,
      ManagedSettingsStore(named: .init("IsleSchedule")),
      ManagedSettingsStore(named: .init("IsleManualWeb")),
      ManagedSettingsStore(named: .init("IsleYoutubeWeb")),
      ManagedSettingsStore(),
    ]
    for store in stores {
      if #available(iOS 17.0, *) {
        store.webContent.blockedByFilter = nil
      }
      // 레거시 youtube 도메인 쉴드 잔존분 제거 — 활성 앱 쉴드(applications/categories)는 보존.
      store.shield.webDomains = nil
      store.shield.webDomainCategories = nil
    }
    #endif
  }

  func writeScheduleSnapshot(json: String) -> Bool {
    IsleAppGroupFiles.writeFile(name: "schedule_snapshot_v1.json", content: json)
  }

  func writeRulesJson(json: String) -> Bool {
    IsleAppGroupFiles.writeFile(name: "rules_v1.json", content: json)
  }

  func appGroupPath() -> String? {
    IsleAppGroupFiles.appGroupPath()
  }

  func saveScheduleSelection(scheduleId: String, bundleId: String? = nil, encoded: String) -> Bool {
    IsleScheduleShieldSync.saveScheduleSelection(
      scheduleId: scheduleId,
      bundleId: bundleId,
      encoded: encoded
    )
  }

  func saveGlobalFallbackSelection(encoded: String) -> Bool {
    guard !encoded.isEmpty else { return false }
    IsleScheduleShieldSync.sharedDefaults?.set(encoded, forKey: "isle.st.global.fallback")
    return true
  }

  func applyActiveScheduleShield(
    scheduleIds: [String],
    domains: [String],
    fallbackEncoded: String?,
    lockdownActive: Bool,
    lockdownAllowedAppsEncoded: String?
  ) -> Bool {
    _ = IsleScheduleShieldSync.saveLockdownAllowedSelection(lockdownAllowedAppsEncoded)
    return IsleScheduleShieldSync.applyActiveSchedules(
      scheduleIds: scheduleIds,
      domains: domains,
      fallbackEncoded: fallbackEncoded,
      lockdownActive: lockdownActive
    )
  }

  func syncShieldFromSnapshot() -> Bool {
    IsleScheduleShieldSync.syncFromSnapshotFile()
  }

  func writeContentBlockerJson(json: String) -> Bool {
    IsleAppGroupFiles.writeFile(name: "content_blocker_v1.json", content: json)
  }

  func syncScheduleDeviceActivities(json: String) -> Bool {
    #if canImport(DeviceActivity)
    return IsleScheduleDeviceActivityBridge.syncFromSchedulesJson(json)
    #else
    return false
    #endif
  }

  func stopScheduleDeviceActivities() {
    #if canImport(DeviceActivity)
    IsleScheduleDeviceActivityBridge.stopAll()
    #endif
  }

  /// Runner.app/PlugIns 안에 확장 .appex 포함 여부 (Xcode 타깃 임베드 후 true).
  func embeddedExtensionsStatus() -> [String: Bool] {
    guard let pluginsURL = Bundle.main.builtInPlugInsURL,
          let names = try? FileManager.default.contentsOfDirectory(atPath: pluginsURL.path)
    else {
      return [
        "deviceActivityMonitor": false,
        "safariContentBlocker": false,
      ]
    }
    return [
      "deviceActivityMonitor": names.contains { $0.contains("IsleDeviceActivityMonitor") },
      "safariContentBlocker": names.contains { $0.contains("IsleSafariContentBlocker") },
    ]
  }

  func openSafariSettings() {
    let candidates = [
      "App-prefs:SAFARI",
      "App-prefs:root=SAFARI",
      UIApplication.openSettingsURLString,
    ]
    for raw in candidates {
      guard let url = URL(string: raw) else { continue }
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return
      }
    }
  }

  func openSettings() {
    let candidates = [
      "App-prefs:SCREEN_TIME",
      "App-prefs:root=SCREEN_TIME",
      UIApplication.openSettingsURLString,
    ]
    for raw in candidates {
      guard let url = URL(string: raw) else { continue }
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return
      }
    }
    if let url = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(url)
    }
  }

  private static let persistenceKeychainService = "com.isle.app.moa.screen_time_persistence"
  private static let persistenceKeychainAccount = "isle_screen_time_persistence_v1"

  func writePersistenceMirror(json: String) -> Bool {
    IsleAppGroupFiles.writeFile(name: "screen_time_persistence_v1.json", content: json)
  }

  func loadPersistenceMirror() -> String? {
    guard let dir = IsleAppGroupFiles.containerURL else { return nil }
    let url = dir.appendingPathComponent("screen_time_persistence_v1.json")
    return try? String(contentsOf: url, encoding: .utf8)
  }

  func savePersistenceKeychain(json: String) -> Bool {
    guard let data = json.data(using: .utf8) else { return false }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.persistenceKeychainService,
      kSecAttrAccount as String: Self.persistenceKeychainAccount,
    ]
    SecItemDelete(query as CFDictionary)
    var add = query
    add[kSecValueData as String] = data
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
  }

  func loadPersistenceKeychain() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.persistenceKeychainService,
      kSecAttrAccount as String: Self.persistenceKeychainAccount,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }
}

final class ScreenTimeBridgePlugin: NSObject, FlutterPlugin {
  private var bridge: Any?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.isle.app/screen_time",
      binaryMessenger: registrar.messenger()
    )
    let instance = ScreenTimeBridgePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    #if canImport(FamilyControls)
    registrar.register(
      IsleScreenTimeLabelsViewFactory(),
      withId: "isle-screen-time-labels"
    )
    #endif
  }

  private func b() -> ScreenTimeBridge? {
    if #available(iOS 16.0, *) {
      if bridge == nil { bridge = ScreenTimeBridge() }
      return bridge as? ScreenTimeBridge
    }
    return nil
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let reply: () -> Void = {
      guard #available(iOS 16.0, *), let bridge = self.b() else {
        if call.method == "authorizationStatus" {
          result("unavailable")
        } else {
          result(false)
        }
        return
      }

      switch call.method {
    case "isAvailable":
      result(bridge.isAvailable())
    case "hasFamilyControlsEntitlement":
      result(bridge.hasFamilyControlsEntitlement())
    case "requestAuthorization":
      bridge.requestAuthorization { ok in result(ok) }
    case "requestAuthorizationDetailed":
      bridge.requestAuthorizationDetailed { dict in result(dict) }
    case "authorizationStatus":
      result(ScreenTimeBridge.authorizationStatusString())
    case "isAuthorized":
      result(bridge.isAuthorized())
    case "applyShield":
      let args = call.arguments as? [String: Any]
      let domains = args?["domains"] as? [String] ?? []
      bridge.applyShield(domains: domains)
      result(nil)
    case "applyScheduleWebDomains":
      let args = call.arguments as? [String: Any]
      let domains = args?["domains"] as? [String] ?? []
      result(bridge.applyScheduleWebDomains(domains: domains))
    case "applyAppShield":
      let args = call.arguments as? [String: Any]
      let encoded = args?["encoded"] as? String ?? ""
      result(bridge.applyAppShield(encoded: encoded))
    case "applyLockdownShield":
      let args = call.arguments as? [String: Any]
      let enable = args?["enable"] as? Bool ?? false
      let allowedAppsEncoded = args?["allowedAppsEncoded"] as? String
      result(bridge.applyLockdownShield(enable: enable, allowedAppsEncoded: allowedAppsEncoded))
    case "clearScheduleEnforcement":
      bridge.clearScheduleEnforcement()
      result(nil)
    case "stopShield":
      bridge.stopShield()
      result(nil)
    case "applyYoutubeWebDomainBlock":
      result(bridge.applyYoutubeWebDomainBlock())
    case "clearWebContentBlock":
      bridge.clearWebContentBlock()
      result(nil)
    case "clearAllWebContentFilters":
      bridge.clearAllWebContentFilters()
      result(nil)
    case "openSettings":
      bridge.openSettings()
      result(nil)
    case "writePersistenceMirror":
      let args = call.arguments as? [String: Any]
      let json = args?["json"] as? String ?? ""
      result(bridge.writePersistenceMirror(json: json))
    case "loadPersistenceMirror":
      result(bridge.loadPersistenceMirror())
    case "savePersistenceKeychain":
      let args = call.arguments as? [String: Any]
      let json = args?["json"] as? String ?? ""
      result(bridge.savePersistenceKeychain(json: json))
    case "loadPersistenceKeychain":
      result(bridge.loadPersistenceKeychain())
    case "writeScheduleSnapshot":
      let args = call.arguments as? [String: Any]
      let json = args?["json"] as? String ?? ""
      result(bridge.writeScheduleSnapshot(json: json))
    case "writeRulesJson":
      let args = call.arguments as? [String: Any]
      let json = args?["json"] as? String ?? ""
      result(bridge.writeRulesJson(json: json))
    case "appGroupPath":
      result(bridge.appGroupPath())
    case "saveScheduleSelection":
      let args = call.arguments as? [String: Any]
      let sid = args?["scheduleId"] as? String ?? ""
      let bundleId = args?["bundleId"] as? String
      let enc = args?["encoded"] as? String ?? ""
      result(bridge.saveScheduleSelection(scheduleId: sid, bundleId: bundleId, encoded: enc))
    case "saveGlobalFallbackSelection":
      let args = call.arguments as? [String: Any]
      let enc = args?["encoded"] as? String ?? ""
      result(bridge.saveGlobalFallbackSelection(encoded: enc))
    case "applyActiveScheduleShield":
      let args = call.arguments as? [String: Any]
      let ids = args?["scheduleIds"] as? [String] ?? []
      let domains = args?["domains"] as? [String] ?? []
      let fallback = args?["fallbackEncoded"] as? String
      let lockdownActive = args?["lockdownActive"] as? Bool ?? false
      let lockdownAllowedAppsEncoded = args?["lockdownAllowedAppsEncoded"] as? String
      result(bridge.applyActiveScheduleShield(
        scheduleIds: ids,
        domains: domains,
        fallbackEncoded: fallback,
        lockdownActive: lockdownActive,
        lockdownAllowedAppsEncoded: lockdownAllowedAppsEncoded
      ))
    case "syncShieldFromSnapshot":
      result(bridge.syncShieldFromSnapshot())
    case "writeContentBlockerJson":
      let args = call.arguments as? [String: Any]
      let json = args?["json"] as? String ?? ""
      result(bridge.writeContentBlockerJson(json: json))
    case "syncScheduleDeviceActivities":
      let args = call.arguments as? [String: Any]
      let json = args?["json"] as? String ?? ""
      result(bridge.syncScheduleDeviceActivities(json: json))
    case "stopScheduleDeviceActivities":
      bridge.stopScheduleDeviceActivities()
      result(nil)
    case "embeddedExtensionsStatus":
      result(bridge.embeddedExtensionsStatus())
    case "openSafariSettings":
      bridge.openSafariSettings()
      result(nil)
    case "pickFamilyActivitySelection":
      #if canImport(FamilyControls)
      let args = call.arguments as? [String: Any]
      let existing = args?["existingEncoded"] as? String
      let additiveOnly = args?["additiveOnly"] as? Bool ?? false
      let purpose = args?["purpose"] as? String ?? "block"
      Task { @MainActor in
        if AuthorizationCenter.shared.authorizationStatus != .approved {
          bridge.requestAuthorization { _ in
            Task { @MainActor in
              await Self.runPicker(existing: existing, additiveOnly: additiveOnly, purpose: purpose, result: result)
            }
          }
        } else {
          await Self.runPicker(existing: existing, additiveOnly: additiveOnly, purpose: purpose, result: result)
        }
      }
      #else
      result(FlutterError(code: "unavailable", message: "FamilyControls not in build", details: nil))
      #endif
    default:
      result(FlutterMethodNotImplemented)
    }
    }

    if Thread.isMainThread {
      reply()
    } else {
      DispatchQueue.main.async(execute: reply)
    }
  }

  @available(iOS 16.0, *)
  @MainActor
  private static func runPicker(
    existing: String?,
    additiveOnly: Bool,
    purpose: String,
    result: @escaping FlutterResult
  ) async {
    #if canImport(FamilyControls)
    guard AuthorizationCenter.shared.authorizationStatus == .approved else {
      result(FlutterError(code: "not_authorized", message: "Screen Time 권한이 필요합니다.", details: nil))
      return
    }
    IsleFamilyActivityPickerUI.present(
      existingEncoded: existing,
      additiveOnly: additiveOnly,
      title: purpose == "lockdownAllow" ? "잠금 중 허용할 앱" : "차단할 앱·카테고리"
    ) { pickResult in
      switch pickResult {
      case .success(let map):
        result(map)
      case .failure(let error as NSError) where error.domain == "IsleScreenTime" && error.code == 2:
        result(nil)
      case .failure(let error):
        result(FlutterError(code: "pick_failed", message: error.localizedDescription, details: nil))
      }
    }
    #else
    result(nil)
    #endif
  }
}

// MARK: - WebView session cookies (YouTube · Instagram)

final class WebSessionBridgePlugin: NSObject, FlutterPlugin {
  private static let sessionDomainHints = ["youtube", "google", "instagram", "facebook"]

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.isle.app/web_session",
      binaryMessenger: registrar.messenger()
    )
    let instance = WebSessionBridgePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private static func isSessionDomain(_ domain: String) -> Bool {
    let d = domain.lowercased()
    return sessionDomainHints.contains { d.contains($0) }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "exportCookies":
      exportCookies(result: result)
    case "importCookies":
      guard let list = call.arguments as? [[String: Any]] else {
        result(FlutterError(code: "bad_args", message: "cookies required", details: nil))
        return
      }
      importCookies(list, result: result)
    case "syncSafariCookiesToWebView":
      syncSafariCookies(result: result)
    case "clearDomainCookies":
      let hint = (call.arguments as? String) ?? ""
      clearDomainCookies(hint: hint, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func exportCookies(result: @escaping FlutterResult) {
    WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
      let filtered = cookies.filter { Self.isSessionDomain($0.domain) }
      let arr: [[String: Any]] = filtered.map { c in
        var m: [String: Any] = [
          "name": c.name,
          "value": c.value,
          "domain": c.domain,
          "path": c.path,
          "isSecure": c.isSecure,
          "isHTTPOnly": c.isHTTPOnly,
        ]
        if let exp = c.expiresDate {
          m["expires"] = exp.timeIntervalSince1970
        }
        return m
      }
      DispatchQueue.main.async { result(arr) }
    }
  }

  private func importCookies(_ list: [[String: Any]], result: @escaping FlutterResult) {
    let store = WKWebsiteDataStore.default().httpCookieStore
    let group = DispatchGroup()
    for item in list {
      guard let name = item["name"] as? String,
            let value = item["value"] as? String,
            let domain = item["domain"] as? String
      else { continue }
      let path = item["path"] as? String ?? "/"
      var props: [HTTPCookiePropertyKey: Any] = [
        .name: name,
        .value: value,
        .domain: domain,
        .path: path,
      ]
      if let exp = item["expires"] as? Double {
        props[.expires] = Date(timeIntervalSince1970: exp)
      }
      if (item["isSecure"] as? Bool) == true {
        props[.secure] = "TRUE"
      }
      guard let cookie = HTTPCookie(properties: props) else { continue }
      group.enter()
      store.setCookie(cookie) { group.leave() }
    }
    group.notify(queue: .main) {
      result(true)
    }
  }

  private func clearDomainCookies(hint: String, result: @escaping FlutterResult) {
    let needle = hint.lowercased()
    let store = WKWebsiteDataStore.default().httpCookieStore
    store.getAllCookies { cookies in
      let targets = cookies.filter { $0.domain.lowercased().contains(needle) }
      if targets.isEmpty {
        DispatchQueue.main.async { result(true) }
        return
      }
      let group = DispatchGroup()
      for cookie in targets {
        group.enter()
        store.delete(cookie) { group.leave() }
      }
      group.notify(queue: .main) {
        result(true)
      }
    }
  }

  private func syncSafariCookies(result: @escaping FlutterResult) {
    let store = WKWebsiteDataStore.default().httpCookieStore
    let shared = HTTPCookieStorage.shared.cookies ?? []
    let filtered = shared.filter { Self.isSessionDomain($0.domain) }
    if filtered.isEmpty {
      result(0)
      return
    }
    let group = DispatchGroup()
    var count = 0
    for cookie in filtered {
      group.enter()
      store.setCookie(cookie) {
        count += 1
        group.leave()
      }
    }
    group.notify(queue: .main) {
      result(count)
    }
  }
}

// MARK: - WKContentRuleList (Safe Browser — Safari CB와 동일 JSON)

#if canImport(WebKit)
final class WebContentRuleBridgePlugin: NSObject, FlutterPlugin {
  private static var compiledRuleList: WKContentRuleList?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.isle.app/web_content_rules",
      binaryMessenger: registrar.messenger()
    )
    let instance = WebContentRuleBridgePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "compileFromAppGroup":
      Self.compileFromAppGroup { ok, err in
        if ok {
          result(true)
        } else {
          result(FlutterError(code: "compile_failed", message: err, details: nil))
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func compileFromAppGroup(completion: @escaping (Bool, String?) -> Void) {
    guard let dir = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: IsleAppIdentity.appGroupId
    ) else {
      completion(false, "no app group")
      return
    }
    let fileURL = dir.appendingPathComponent("content_blocker_v1.json")
    guard let json = try? String(contentsOf: fileURL, encoding: .utf8), !json.isEmpty else {
      completion(false, "no rules file")
      return
    }
    WKContentRuleListStore.default().compileContentRuleList(
      forIdentifier: "IsleSafeBrowserRules",
      encodedContentRuleList: json
    ) { list, error in
      if let list = list {
        compiledRuleList = list
        completion(true, nil)
      } else {
        completion(false, error?.localizedDescription ?? "compile error")
      }
    }
  }
}
#endif
