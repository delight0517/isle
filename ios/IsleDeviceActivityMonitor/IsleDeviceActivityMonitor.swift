import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum IsleAppLimitStorage {
  static let appGroupId: String = {
    if let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String, !id.isEmpty {
      return id
    }
    return "group.com.isle.app.moa"
  }()
  static let limitsKey = "isle_app_limits_registry"

  static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

  static func loadRegistry() -> [[String: Any]] {
    defaults?.array(forKey: limitsKey) as? [[String: Any]] ?? []
  }
}

/// Xcode: File → New → Target → Device Activity Monitor Extension
/// Bundle ID 예: com.isle.app.isleDeviceActivityMonitor
/// App Group `group.com.isle.app` + Family Controls capability
final class IsleDeviceActivityMonitor: DeviceActivityMonitor {
  private let store = ManagedSettingsStore(named: .init("IsleAppLimits"))

  override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
    let prefix = "com.isle.app.limit.event."
    guard event.rawValue.hasPrefix(prefix) else { return }
    guard let item = IsleAppLimitStorage.loadRegistry().first(where: { row in
      (row["activityNames"] as? [String])?.contains(activity.rawValue) == true
    }),
          let encoded = item["encoded"] as? String,
          let data = Data(base64Encoded: encoded),
          let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    else { return }

    store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    if !selection.categoryTokens.isEmpty {
      store.shield.applicationCategories = .specific(selection.categoryTokens, except: Set())
    }
  }

  override func intervalDidStart(for activity: DeviceActivityName) {
    if activity.rawValue.hasPrefix("com.isle.app.schedule.") {
      _ = IsleScheduleShieldSyncExtension.syncFromSnapshotFile()
    }
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    if activity.rawValue.hasPrefix("com.isle.app.limit.") {
      store.shield.applications = nil
      store.shield.applicationCategories = nil
    }
    if activity.rawValue.hasPrefix("com.isle.app.schedule.") {
      _ = IsleScheduleShieldSyncExtension.syncFromSnapshotFile()
    }
  }
}

/// 확장 타깃 전용 — Runner의 IsleScheduleShieldSync와 동일 로직 (파일 복제).
enum IsleScheduleShieldSyncExtension {
  static let appGroupId: String = {
    if let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String, !id.isEmpty {
      return id
    }
    return "group.com.isle.app.moa"
  }()
  static let snapshotFileName = "schedule_snapshot_v1.json"
  static let legacySelectionKeyPrefix = "isle.st.sel.v2."
  static let selectionKeyPrefix = "isle.st.sel.v3."
  static let lockdownAllowedAppsKey = "isle.st.lockdown.allowedApps.v1"

  static var sharedDefaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

  static func selectionKey(for scheduleId: String, bundleId: String? = nil) -> String {
    guard let bundleId, !bundleId.isEmpty else { return legacySelectionKeyPrefix + scheduleId }
    return selectionKeyPrefix + scheduleId + "." + bundleId
  }

  static func loadScheduleSelection(scheduleId: String, bundleId: String? = nil) -> String? {
    sharedDefaults?.string(forKey: selectionKey(for: scheduleId, bundleId: bundleId))
  }

  static func allSelections(forSchedule scheduleId: String) -> [String] {
    guard let defaults = sharedDefaults else { return [] }
    let prefix = selectionKeyPrefix + scheduleId + "."
    return defaults.dictionaryRepresentation().keys
      .filter { $0.hasPrefix(prefix) }
      .compactMap { defaults.string(forKey: $0) }
      .filter { !$0.isEmpty }
  }

  static func unionSelections(_ encodedList: [String]) -> FamilyActivitySelection? {
    var merged = FamilyActivitySelection()
    var hasAny = false
    for encoded in encodedList {
      guard let data = Data(base64Encoded: encoded),
            let sel = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
      else { continue }
      merged.applicationTokens.formUnion(sel.applicationTokens)
      merged.categoryTokens.formUnion(sel.categoryTokens)
      merged.webDomainTokens.formUnion(sel.webDomainTokens)
      hasAny = true
    }
    return hasAny ? merged : nil
  }

  @discardableResult
  static func syncFromSnapshotFile() -> Bool {
    guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId),
          let data = try? Data(contentsOf: dir.appendingPathComponent(snapshotFileName)),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return false }

    if root["masterEnabled"] as? Bool == false {
      ManagedSettingsStore(named: .init("IsleSchedule")).clearAllSettings()
      return true
    }

    let ids = root["activeScheduleIds"] as? [String] ?? []
    var domains = Set<String>()
    if let shieldList = root["shieldDomains"] as? [String] {
      for d in shieldList { domains.insert(d.lowercased()) }
    }
    if let schedules = root["schedules"] as? [[String: Any]] {
      let activeSet = Set(ids)
      for s in schedules {
        guard let sid = s["id"] as? String, activeSet.contains(sid) else { continue }
        let mode = s["enforcementMode"] as? String ?? "full_block"
        if mode == "limit_in_slot" { continue }
        if domains.isEmpty, let ds = s["domains"] as? [String] {
          for d in ds { domains.insert(d.lowercased()) }
        }
      }
    }
    let activeSet = Set(ids)
    let lockdownActive = (root["schedules"] as? [[String: Any]] ?? []).contains {
      ($0["lockdownAllApps"] as? Bool) == true && activeSet.contains($0["id"] as? String ?? "")
    }
    var encodings: [String] = []
    for id in ids {
      let perBundle = allSelections(forSchedule: id)
      if !perBundle.isEmpty {
        encodings.append(contentsOf: perBundle)
      } else if let legacy = loadScheduleSelection(scheduleId: id), !legacy.isEmpty {
        encodings.append(legacy)
      }
    }
    if encodings.isEmpty, let fb = sharedDefaults?.string(forKey: "isle.st.global.fallback"), !fb.isEmpty {
      encodings = [fb]
    }
    guard let merged = unionSelections(encodings) ?? (lockdownActive ? FamilyActivitySelection() : nil) else { return false }
    let st = ManagedSettingsStore(named: .init("IsleSchedule"))
    let allowed = sharedDefaults?.string(forKey: lockdownAllowedAppsKey)
      .flatMap { Data(base64Encoded: $0) }
      .flatMap { try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: $0) }
      .map(\.applicationTokens) ?? Set<ApplicationToken>()
    var blockedApps = merged.applicationTokens
    if lockdownActive { blockedApps.subtract(allowed) }
    st.shield.applications = blockedApps.isEmpty ? nil : blockedApps
    if lockdownActive {
      st.shield.applicationCategories = .all(except: allowed)
    } else if !merged.categoryTokens.isEmpty {
      st.shield.applicationCategories = .specific(merged.categoryTokens, except: Set())
    } else {
      st.shield.applicationCategories = nil
    }
    if #available(iOS 17.0, *) {
      st.webContent.blockedByFilter = nil
    }
    return true
  }
}
