import Flutter
import UIKit

#if canImport(FamilyControls)
import FamilyControls
#endif

final class AppLimitPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.isle.app/app_limits",
      binaryMessenger: registrar.messenger()
    )
    let instance = AppLimitPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      #if canImport(DeviceActivity)
      result(true)
      #else
      result(false)
      #endif
    case "requestAuthorization":
      #if canImport(FamilyControls)
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
      #else
      result(false)
      #endif
    case "hasUsageAccess":
      result(true)
    case "openUsageAccessSettings":
      result(nil)
    case "registerLimit":
      #if canImport(DeviceActivity)
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String,
            let minutes = args["minutes"] as? Int,
            let windowMinutes = args["windowMinutes"] as? Int,
            let encoded = args["iosEncoded"] as? String,
            !encoded.isEmpty
      else {
        result(false)
        return
      }
      let label = args["label"] as? String ?? id
      let title = args["interventionTitle"] as? String ?? ""
      let body = args["interventionBody"] as? String ?? ""
      let scope = args["scope"] as? String ?? "always"
      let slots = args["slots"] as? [[String: Any]]
      result(
        IsleAppLimitBridge.registerLimit(
          ruleId: id,
          minutes: minutes,
          windowMinutes: windowMinutes,
          encoded: encoded,
          label: label,
          interventionTitle: title,
          interventionBody: body,
          scope: scope,
          slots: slots
        )
      )
      #else
      result(false)
      #endif
    case "unregisterLimit":
      #if canImport(DeviceActivity)
      let id = (call.arguments as? [String: Any])?["id"] as? String ?? ""
      IsleAppLimitBridge.unregisterLimit(ruleId: id)
      #endif
      result(nil)
    case "usageMinutesToday":
      result(0)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
