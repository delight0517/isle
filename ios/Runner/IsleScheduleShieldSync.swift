import Foundation

#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
#endif

/// App Group 스케줄 스냅샷 + 스케줄별 selection blob → OS 쉴드 (BGTask·확장 공용).
enum IsleScheduleShieldSync {
  static let appGroupId = IsleAppIdentity.appGroupId
  static let snapshotFileName = "schedule_snapshot_v1.json"
  static let legacySelectionKeyPrefix = "isle.st.sel.v2."
  static let selectionKeyPrefix = "isle.st.sel.v3."
  static let lockdownAllowedAppsKey = "isle.st.lockdown.allowedApps.v1"

  static var sharedDefaults: UserDefaults? {
    UserDefaults(suiteName: appGroupId)
  }

  static func selectionKey(for scheduleId: String, bundleId: String? = nil) -> String {
    guard let bundleId, !bundleId.isEmpty else {
      return legacySelectionKeyPrefix + scheduleId
    }
    return selectionKeyPrefix + scheduleId + "." + bundleId
  }

  @discardableResult
  static func saveScheduleSelection(scheduleId: String, bundleId: String? = nil, encoded: String) -> Bool {
    guard !scheduleId.isEmpty, !encoded.isEmpty else { return false }
    sharedDefaults?.set(encoded, forKey: selectionKey(for: scheduleId, bundleId: bundleId))
    return true
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

  @discardableResult
  static func saveLockdownAllowedSelection(_ encoded: String?) -> Bool {
    guard let defaults = sharedDefaults else { return false }
    if let encoded, !encoded.isEmpty {
      defaults.set(encoded, forKey: lockdownAllowedAppsKey)
    } else {
      defaults.removeObject(forKey: lockdownAllowedAppsKey)
    }
    return true
  }

  #if canImport(FamilyControls)
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
  static func applyShield(
    selection: FamilyActivitySelection,
    domains: [String],
    lockdownActive: Bool = false
  ) -> Bool {
    guard AuthorizationCenter.shared.authorizationStatus == .approved else { return false }
    let store = ManagedSettingsStore(named: .init("IsleSchedule"))
    let allowed = lockdownActive
      ? sharedDefaults?.string(forKey: lockdownAllowedAppsKey)
        .flatMap { Data(base64Encoded: $0) }
        .flatMap { try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: $0) }
        .map(\.applicationTokens) ?? Set()
      : Set<ApplicationToken>()
    var blockedApps = selection.applicationTokens
    blockedApps.subtract(allowed)
    if blockedApps.isEmpty {
      store.shield.applications = nil
    } else {
      store.shield.applications = blockedApps
    }
    if lockdownActive {
      store.shield.applicationCategories = .all(except: allowed)
    } else if selection.categoryTokens.isEmpty {
      store.shield.applicationCategories = nil
    } else {
      store.shield.applicationCategories = .specific(selection.categoryTokens, except: Set())
    }
    if selection.webDomainTokens.isEmpty {
      store.shield.webDomains = nil
    } else {
      store.shield.webDomains = selection.webDomainTokens
    }
    // youtube.com 등 도메인 OS webContent 차단은 Isle WKWebView까지 막음 → 사용 안 함.
    // Safari 전용 차단은 Content Blocker 확장 + 앱 아이콘 쉴드만 사용.
    if #available(iOS 17.0, *) {
      store.webContent.blockedByFilter = nil
    }
    return true
  }

  @discardableResult
  static func applyActiveSchedules(
    scheduleIds: [String],
    domains: [String],
    fallbackEncoded: String?,
    lockdownActive: Bool = false
  ) -> Bool {
    guard AuthorizationCenter.shared.authorizationStatus == .approved else { return false }
    var encodings: [String] = []
    for id in scheduleIds {
      let perBundle = allSelections(forSchedule: id)
      if !perBundle.isEmpty {
        encodings.append(contentsOf: perBundle)
      } else if let legacy = loadScheduleSelection(scheduleId: id), !legacy.isEmpty {
        encodings.append(legacy)
      }
    }
    if encodings.isEmpty, let fb = fallbackEncoded, !fb.isEmpty {
      encodings = [fb]
    }
    if let merged = unionSelections(encodings) {
      return applyShield(selection: merged, domains: domains, lockdownActive: lockdownActive)
    }
    if domains.isEmpty && !lockdownActive {
      ManagedSettingsStore(named: .init("IsleSchedule")).clearAllSettings()
      return true
    }
    return applyShield(selection: FamilyActivitySelection(), domains: domains, lockdownActive: lockdownActive)
  }

  @discardableResult
  static func syncFromSnapshotFile() -> Bool {
    guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
      return false
    }
    let url = dir.appendingPathComponent(snapshotFileName)
    guard let data = try? Data(contentsOf: url),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return false }

    let master = root["masterEnabled"] as? Bool ?? true
    if !master {
      ManagedSettingsStore(named: .init("IsleSchedule")).clearAllSettings()
      return true
    }

    let ids = root["activeScheduleIds"] as? [String] ?? []
    let activeSet = Set(ids)
    let lockdownActive = (root["schedules"] as? [[String: Any]] ?? []).contains {
      ($0["lockdownAllApps"] as? Bool) == true && activeSet.contains($0["id"] as? String ?? "")
    }
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
    let fallback = sharedDefaults?.string(forKey: "isle.st.global.fallback")
    return applyActiveSchedules(
      scheduleIds: ids,
      domains: Array(domains),
      fallbackEncoded: fallback,
      lockdownActive: lockdownActive
    )
  }
  #else
  @discardableResult
  static func applyActiveSchedules(
    scheduleIds: [String],
    domains: [String],
    fallbackEncoded: String?,
    lockdownActive: Bool = false
  ) -> Bool { false }

  @discardableResult
  static func syncFromSnapshotFile() -> Bool { false }
  #endif
}
