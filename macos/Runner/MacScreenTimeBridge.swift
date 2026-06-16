import Cocoa
import FlutterMacOS
import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
#endif

private enum IsleScreenTimeStores {
  #if canImport(ManagedSettings)
  static let schedule = ManagedSettingsStore(named: .init("IsleSchedule"))
  static let manualWeb = ManagedSettingsStore(named: .init("IsleManualWeb"))
  #endif
}

#if canImport(FamilyControls)
private struct IsleFamilyPickerContainer: View {
  @State private var selection: FamilyActivitySelection
  let onFinish: (FamilyActivitySelection) -> Void
  let onCancel: () -> Void

  init(
    initial: FamilyActivitySelection,
    onFinish: @escaping (FamilyActivitySelection) -> Void,
    onCancel: @escaping () -> Void
  ) {
    _selection = State(initialValue: initial)
    self.onFinish = onFinish
    self.onCancel = onCancel
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button("취소") { onCancel() }
        Spacer()
        Text("차단할 앱·카테고리")
          .font(.headline)
        Spacer()
        Button("완료") { onFinish(selection) }
          .keyboardShortcut(.defaultAction)
      }
      .padding(12)
      Divider()
      FamilyActivityPicker(selection: $selection)
        .frame(minWidth: 420, minHeight: 480)
    }
    .frame(width: 480, height: 560)
  }
}

enum IsleFamilyActivityPickerUI {
  @MainActor
  static func present(
    existingEncoded: String?,
    completion: @escaping (Result<[String: Any], Error>) -> Void
  ) {
    var initial = FamilyActivitySelection()
    if let existingEncoded,
       let data = Data(base64Encoded: existingEncoded),
       let decoded = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
      initial = decoded
    }

    guard let parent = NSApp.mainWindow?.contentViewController else {
      completion(.failure(NSError(domain: "IsleScreenTime", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "메인 창을 찾을 수 없습니다.",
      ])))
      return
    }

    var sheetRef: NSWindow?
    let hosting = NSHostingController(
      rootView: IsleFamilyPickerContainer(
        initial: initial,
        onFinish: { selection in
          sheetRef?.close()
          sheetRef = nil
          do {
            let data = try PropertyListEncoder().encode(selection)
            completion(.success([
              "encoded": data.base64EncodedString(),
              "applicationCount": selection.applicationTokens.count,
              "categoryCount": selection.categoryTokens.count,
              "webDomainCount": selection.webDomainTokens.count,
            ]))
          } catch {
            completion(.failure(error))
          }
        },
        onCancel: {
          sheetRef?.close()
          sheetRef = nil
          completion(.failure(NSError(domain: "IsleScreenTime", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "cancelled",
          ])))
        }
      )
    )

    let sheet = NSWindow(contentViewController: hosting)
    sheet.styleMask = [.titled, .closable]
    sheet.title = "Isle — 앱 선택"
    sheet.center()
    sheetRef = sheet
    parent.presentAsSheet(sheet)
  }
}
#endif

@available(macOS 13.0, *)
final class MacScreenTimeBridge: NSObject {
  static let shared = MacScreenTimeBridge()

  func isAvailable() -> Bool {
    #if canImport(FamilyControls)
    return true
    #else
    return false
    #endif
  }

  func requestAuthorization(completion: @escaping (Bool) -> Void) {
    #if canImport(FamilyControls)
    Task { @MainActor in
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        completion(AuthorizationCenter.shared.authorizationStatus == .approved)
      } catch {
        completion(false)
      }
    }
    #else
    completion(false)
    #endif
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

  func applyScheduleWebDomains(domains: [String]) -> Bool {
    #if canImport(FamilyControls) && canImport(ManagedSettings)
    guard AuthorizationCenter.shared.authorizationStatus == .approved else { return false }
    if #available(macOS 14.0, *) {
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
      store.shield.webDomains = selection.webDomainTokens
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

  func applyYoutubeWebDomainBlock() -> Bool {
    clearAllWebContentFilters()
    return false
  }

  func clearWebContentBlock() {
    clearAllWebContentFilters()
  }

  func clearAllWebContentFilters() {
    #if canImport(ManagedSettings)
    if #available(macOS 14.0, *) {
      IsleScreenTimeStores.manualWeb.webContent.blockedByFilter = nil
      IsleScreenTimeStores.schedule.webContent.blockedByFilter = nil
    }
    #endif
  }

  func openSettings() {
    let urls = [
      "x-apple.systempreferences:com.apple.Screen-Time",
      "x-apple.systempreferences:com.apple.preference.screentime",
    ]
    for raw in urls {
      if let url = URL(string: raw), NSWorkspace.shared.open(url) {
        return
      }
    }
  }
}

final class MacScreenTimeBridgePlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.isle.app/screen_time",
      binaryMessenger: registrar.messenger
    )
    let instance = MacScreenTimeBridgePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let reply: () -> Void = {
      guard #available(macOS 13.0, *) else {
        if call.method == "authorizationStatus" {
          result("unavailable")
        } else {
          result(false)
        }
        return
      }
      let bridge = MacScreenTimeBridge.shared

      switch call.method {
    case "isAvailable":
      result(bridge.isAvailable())
    case "requestAuthorization":
      bridge.requestAuthorization { ok in result(ok) }
    case "authorizationStatus":
      result(MacScreenTimeBridge.authorizationStatusString())
    case "isAuthorized":
      result(bridge.isAuthorized())
    case "applyShield":
      let args = call.arguments as? [String: Any]
      let domains = args?["domains"] as? [String] ?? []
      _ = bridge.applyScheduleWebDomains(domains: domains)
      result(nil)
    case "applyScheduleWebDomains":
      let args = call.arguments as? [String: Any]
      let domains = args?["domains"] as? [String] ?? []
      result(bridge.applyScheduleWebDomains(domains: domains))
    case "applyAppShield":
      let args = call.arguments as? [String: Any]
      let encoded = args?["encoded"] as? String ?? ""
      result(bridge.applyAppShield(encoded: encoded))
    case "clearScheduleEnforcement":
      bridge.clearScheduleEnforcement()
      result(nil)
    case "stopShield":
      bridge.clearScheduleEnforcement()
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
    case "pickFamilyActivitySelection":
      #if canImport(FamilyControls)
      let args = call.arguments as? [String: Any]
      let existing = args?["existingEncoded"] as? String
      Task { @MainActor in
        if AuthorizationCenter.shared.authorizationStatus != .approved {
          bridge.requestAuthorization { _ in
            Task { @MainActor in
              await Self.runPicker(existing: existing, result: result)
            }
          }
        } else {
          await Self.runPicker(existing: existing, result: result)
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

  @available(macOS 13.0, *)
  @MainActor
  private static func runPicker(existing: String?, result: @escaping FlutterResult) async {
    #if canImport(FamilyControls)
    guard AuthorizationCenter.shared.authorizationStatus == .approved else {
      result(FlutterError(code: "not_authorized", message: "Screen Time 권한이 필요합니다.", details: nil))
      return
    }
    IsleFamilyActivityPickerUI.present(existingEncoded: existing) { pickResult in
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
