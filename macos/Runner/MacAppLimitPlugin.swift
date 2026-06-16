import Cocoa
import FlutterMacOS

#if canImport(FamilyControls)
import FamilyControls
#endif

final class MacAppLimitPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.isle.app/app_limits",
      binaryMessenger: registrar.messenger
    )
    let instance = MacAppLimitPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      #if os(macOS) && canImport(FamilyControls)
      if #available(macOS 13.0, *) {
        result(true)
      } else {
        result(false)
      }
      #else
      result(false)
      #endif
    case "requestAuthorization":
      #if canImport(FamilyControls)
      if #available(macOS 13.0, *) {
        Task {
          do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await MainActor.run {
              result(AuthorizationCenter.shared.authorizationStatus == .approved)
            }
          } catch {
            await MainActor.run { result(false) }
          }
        }
      } else {
        result(false)
      }
      #else
      result(false)
      #endif
    case "hasUsageAccess":
      result(true)
    case "openUsageAccessSettings":
      MacScreenTimeBridge.shared.openSettings()
      result(nil)
    case "registerLimit":
      #if os(macOS) && canImport(FamilyControls)
      guard #available(macOS 13.0, *),
            let args = call.arguments as? [String: Any],
            let id = args["id"] as? String,
            let minutes = args["minutes"] as? Int,
            let encoded = args["iosEncoded"] as? String,
            !encoded.isEmpty
      else {
        result(false)
        return
      }
      let label = args["label"] as? String ?? id
      let title = args["interventionTitle"] as? String ?? ""
      let body = args["interventionBody"] as? String ?? ""
      result(
        IsleAppLimitBridge.registerLimit(
          ruleId: id,
          minutes: minutes,
          encoded: encoded,
          label: label,
          interventionTitle: title,
          interventionBody: body
        )
      )
      #else
      result(false)
      #endif
    case "unregisterLimit":
      #if os(macOS) && canImport(FamilyControls)
      if #available(macOS 13.0, *) {
        let id = (call.arguments as? [String: Any])?["id"] as? String ?? ""
        IsleAppLimitBridge.unregisterLimit(ruleId: id)
      }
      #endif
      result(nil)
    case "usageMinutesToday":
      result(0)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
