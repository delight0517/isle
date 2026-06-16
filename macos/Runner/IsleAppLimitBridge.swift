import Foundation

#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
#endif

enum IsleAppLimitStorage {
  static let appGroupId = "group.com.isle.app"
  static let limitsKey = "isle_app_limits_registry"

  static var defaults: UserDefaults? {
    UserDefaults(suiteName: appGroupId)
  }

  static func saveRegistry(_ items: [[String: Any]]) {
    defaults?.set(items, forKey: limitsKey)
  }

  static func loadRegistry() -> [[String: Any]] {
    defaults?.array(forKey: limitsKey) as? [[String: Any]] ?? []
  }
}

#if os(iOS) && canImport(DeviceActivity) && canImport(FamilyControls)
import DeviceActivity

enum IsleAppLimitBridge {
  private static let limitStore = ManagedSettingsStore(named: .init("IsleAppLimits"))

  static func activityName(ruleId: String) -> DeviceActivityName {
    let safe = ruleId.replacingOccurrences(of: ":", with: "-")
    return DeviceActivityName("com.isle.app.limit.\(safe)")
  }

  static func eventName(ruleId: String) -> DeviceActivityEvent.Name {
    DeviceActivityEvent.Name("com.isle.app.limit.event.\(ruleId)")
  }

  @discardableResult
  static func registerLimit(
    ruleId: String,
    minutes: Int,
    encoded: String,
    label: String,
    interventionTitle: String,
    interventionBody: String
  ) -> Bool {
    guard AuthorizationCenter.shared.authorizationStatus == .approved,
          minutes > 0,
          let data = Data(base64Encoded: encoded),
          let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data),
          !selection.applicationTokens.isEmpty
    else { return false }

    var registry = IsleAppLimitStorage.loadRegistry().filter { ($0["id"] as? String) != ruleId }
    registry.append([
      "id": ruleId,
      "minutes": minutes,
      "encoded": encoded,
      "label": label,
      "interventionTitle": interventionTitle,
      "interventionBody": interventionBody,
    ])
    IsleAppLimitStorage.saveRegistry(registry)

    let schedule = DeviceActivitySchedule(
      intervalStart: DateComponents(hour: 0, minute: 0),
      intervalEnd: DateComponents(hour: 23, minute: 59),
      repeats: true
    )

    let threshold = DateComponents(minute: max(1, minutes))
    let event: DeviceActivityEvent
    if #available(iOS 17.4, *) {
      event = DeviceActivityEvent(
        applications: selection.applicationTokens,
        threshold: threshold,
        includesPastActivity: true
      )
    } else {
      event = DeviceActivityEvent(
        applications: selection.applicationTokens,
        threshold: threshold
      )
    }

    let center = DeviceActivityCenter()
    let name = activityName(ruleId: ruleId)
    let ev = eventName(ruleId: ruleId)
    center.stopMonitoring([name])
    do {
      try center.startMonitoring(name, during: schedule, events: [ev: event])
      return true
    } catch {
      return false
    }
  }

  static func unregisterLimit(ruleId: String) {
    var registry = IsleAppLimitStorage.loadRegistry()
    registry.removeAll { ($0["id"] as? String) == ruleId }
    IsleAppLimitStorage.saveRegistry(registry)

    let center = DeviceActivityCenter()
    center.stopMonitoring([activityName(ruleId: ruleId)])
    limitStore.shield.applications = nil
    limitStore.shield.applicationCategories = nil
  }

  static func applyShieldForRule(encoded: String) -> Bool {
    guard let data = Data(base64Encoded: encoded),
          let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    else { return false }
    if selection.applicationTokens.isEmpty {
      limitStore.shield.applications = nil
    } else {
      limitStore.shield.applications = selection.applicationTokens
    }
    return true
  }
}

#elseif os(macOS) && canImport(FamilyControls)
@available(macOS 13.0, *)
enum IsleAppLimitBridge {
  @discardableResult
  static func registerLimit(
    ruleId: String,
    minutes: Int,
    encoded: String,
    label: String,
    interventionTitle: String,
    interventionBody: String
  ) -> Bool {
    guard minutes > 0, !encoded.isEmpty else { return false }
    guard MacScreenTimeBridge.shared.isAuthorized() else { return false }

    var registry = IsleAppLimitStorage.loadRegistry().filter { ($0["id"] as? String) != ruleId }
    registry.append([
      "id": ruleId,
      "minutes": minutes,
      "encoded": encoded,
      "label": label,
      "interventionTitle": interventionTitle,
      "interventionBody": interventionBody,
    ])
    IsleAppLimitStorage.saveRegistry(registry)
    return MacScreenTimeBridge.shared.applyAppShield(encoded: encoded)
  }

  static func unregisterLimit(ruleId: String) {
    var registry = IsleAppLimitStorage.loadRegistry()
    registry.removeAll { ($0["id"] as? String) == ruleId }
    IsleAppLimitStorage.saveRegistry(registry)
    if registry.isEmpty {
      MacScreenTimeBridge.shared.clearScheduleEnforcement()
    }
  }

  static func applyShieldForRule(encoded: String) -> Bool {
    MacScreenTimeBridge.shared.applyAppShield(encoded: encoded)
  }
}

#else
enum IsleAppLimitBridge {
  @discardableResult
  static func registerLimit(
    ruleId: String,
    minutes: Int,
    encoded: String,
    label: String,
    interventionTitle: String,
    interventionBody: String
  ) -> Bool { false }

  static func unregisterLimit(ruleId: String) {}

  static func applyShieldForRule(encoded: String) -> Bool { false }
}
#endif
