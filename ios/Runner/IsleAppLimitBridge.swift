import Foundation

#if canImport(FamilyControls)
import DeviceActivity
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

#if canImport(DeviceActivity) && canImport(FamilyControls)
enum IsleAppLimitBridge {
  private static let limitStore = ManagedSettingsStore(named: .init("IsleAppLimits"))

  static func activityName(ruleId: String) -> DeviceActivityName {
    let safe = ruleId.replacingOccurrences(of: ":", with: "-")
    return DeviceActivityName("com.isle.app.limit.\(safe)")
  }

  static func activityNames(ruleId: String, windowMinutes: Int) -> [DeviceActivityName] {
    if windowMinutes == 60 {
      let safe = ruleId.replacingOccurrences(of: ":", with: "-")
      return (0..<24).map { h in
        DeviceActivityName("com.isle.app.limit.\(safe).h\(h)")
      }
    }
    return [activityName(ruleId: ruleId)]
  }

  static func eventName(ruleId: String) -> DeviceActivityEvent.Name {
    DeviceActivityEvent.Name("com.isle.app.limit.event.\(ruleId)")
  }

  private static func dartWeekdayToCalendar(_ day: Int) -> Int {
    day == 6 ? 1 : day + 2
  }

  private static func coversMinute(_ minute: Int, start: Int, end: Int) -> Bool {
    if start <= end {
      return minute >= start && minute < end
    }
    return minute >= start || minute < end
  }

  private static func hourInSlot(day: Int, hour: Int, slots: [[String: Any]]) -> Bool {
    for slot in slots {
      let d = (slot["day"] as? Int) ?? -1
      if d != day { continue }
      let start = (slot["startMinute"] as? Int) ?? 0
      let end = (slot["endMinute"] as? Int) ?? 0
      let hourStart = hour * 60
      for m in hourStart..<(hourStart + 60) {
        if coversMinute(m % (24 * 60), start: start, end: end) { return true }
      }
    }
    return false
  }

  private static func scopedActivityName(ruleId: String, day: Int, hour: Int) -> DeviceActivityName {
    let safe = ruleId.replacingOccurrences(of: ":", with: "-")
    return DeviceActivityName("com.isle.app.limit.\(safe).d\(day).h\(hour)")
  }

  @discardableResult
  static func registerLimit(
    ruleId: String,
    minutes: Int,
    windowMinutes: Int,
    encoded: String,
    label: String,
    interventionTitle: String,
    interventionBody: String,
    scope: String = "always",
    slots: [[String: Any]]? = nil
  ) -> Bool {
    unregisterLimit(ruleId: ruleId)

    guard AuthorizationCenter.shared.authorizationStatus == .approved,
          minutes > 0,
          let data = Data(base64Encoded: encoded),
          let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data),
          !selection.applicationTokens.isEmpty
    else { return false }

    if scope != "always", let slots = slots, !slots.isEmpty, windowMinutes == 60 {
      return registerLimitScoped(
        ruleId: ruleId,
        minutes: minutes,
        encoded: encoded,
        label: label,
        interventionTitle: interventionTitle,
        interventionBody: interventionBody,
        scope: scope,
        slots: slots,
        selection: selection
      )
    }

    return registerLimitAlways(
      ruleId: ruleId,
      minutes: minutes,
      windowMinutes: windowMinutes,
      encoded: encoded,
      label: label,
      interventionTitle: interventionTitle,
      interventionBody: interventionBody,
      selection: selection
    )
  }

  private static func registerLimitAlways(
    ruleId: String,
    minutes: Int,
    windowMinutes: Int,
    encoded: String,
    label: String,
    interventionTitle: String,
    interventionBody: String,
    selection: FamilyActivitySelection
  ) -> Bool {
    let names = activityNames(ruleId: ruleId, windowMinutes: windowMinutes)
    let center = DeviceActivityCenter()

    var registry = IsleAppLimitStorage.loadRegistry().filter { ($0["id"] as? String) != ruleId }
    registry.append([
      "id": ruleId,
      "minutes": minutes,
      "windowMinutes": windowMinutes,
      "encoded": encoded,
      "label": label,
      "interventionTitle": interventionTitle,
      "interventionBody": interventionBody,
      "scope": "always",
      "activityNames": names.map(\.rawValue),
    ])
    IsleAppLimitStorage.saveRegistry(registry)

    let event = makeThresholdEvent(selection: selection, minutes: minutes)
    let ev = eventName(ruleId: ruleId)

    if windowMinutes == 60 {
      for h in 0..<24 {
        let start = DateComponents(hour: h, minute: 0)
        let end = DateComponents(hour: (h + 1) % 24, minute: 0)
        let schedule = DeviceActivitySchedule(
          intervalStart: start,
          intervalEnd: end,
          repeats: true
        )
        do {
          try center.startMonitoring(names[h], during: schedule, events: [ev: event])
        } catch {
          return false
        }
      }
      return true
    }

    let schedule = DeviceActivitySchedule(
      intervalStart: DateComponents(hour: 0, minute: 0),
      intervalEnd: DateComponents(hour: 23, minute: 59),
      repeats: true
    )
    do {
      try center.startMonitoring(names[0], during: schedule, events: [ev: event])
      return true
    } catch {
      return false
    }
  }

  private static func registerLimitScoped(
    ruleId: String,
    minutes: Int,
    encoded: String,
    label: String,
    interventionTitle: String,
    interventionBody: String,
    scope: String,
    slots: [[String: Any]],
    selection: FamilyActivitySelection
  ) -> Bool {
    let inSlot = scope == "in_slot"
    let center = DeviceActivityCenter()
    var registered: [String] = []
    let event = makeThresholdEvent(selection: selection, minutes: minutes)
    let ev = eventName(ruleId: ruleId)

    for day in 0..<7 {
      let weekday = dartWeekdayToCalendar(day)
      for hour in 0..<24 {
        let inside = hourInSlot(day: day, hour: hour, slots: slots)
        if inSlot != inside { continue }
        let name = scopedActivityName(ruleId: ruleId, day: day, hour: hour)
        let start = DateComponents(hour: hour, minute: 0, weekday: weekday)
        let end = DateComponents(hour: (hour + 1) % 24, minute: 0, weekday: weekday)
        let schedule = DeviceActivitySchedule(
          intervalStart: start,
          intervalEnd: end,
          repeats: true
        )
        do {
          try center.startMonitoring(name, during: schedule, events: [ev: event])
          registered.append(name.rawValue)
        } catch {
          return false
        }
      }
    }

    var registry = IsleAppLimitStorage.loadRegistry().filter { ($0["id"] as? String) != ruleId }
    registry.append([
      "id": ruleId,
      "minutes": minutes,
      "windowMinutes": 60,
      "encoded": encoded,
      "label": label,
      "interventionTitle": interventionTitle,
      "interventionBody": interventionBody,
      "scope": scope,
      "activityNames": registered,
    ])
    IsleAppLimitStorage.saveRegistry(registry)
    return !registered.isEmpty
  }

  private static func makeThresholdEvent(
    selection: FamilyActivitySelection,
    minutes: Int
  ) -> DeviceActivityEvent {
    let threshold = DateComponents(minute: max(1, minutes))
    if #available(iOS 17.4, *) {
      return DeviceActivityEvent(
        applications: selection.applicationTokens,
        threshold: threshold,
        includesPastActivity: true
      )
    }
    return DeviceActivityEvent(
      applications: selection.applicationTokens,
      threshold: threshold
    )
  }

  static func unregisterLimit(ruleId: String) {
    let oldRegistry = IsleAppLimitStorage.loadRegistry()
    var registry = oldRegistry
    registry.removeAll { ($0["id"] as? String) == ruleId }
    IsleAppLimitStorage.saveRegistry(registry)

    let center = DeviceActivityCenter()
    if let item = oldRegistry.first(where: { ($0["id"] as? String) == ruleId }),
       let raws = item["activityNames"] as? [String] {
      center.stopMonitoring(raws.map { DeviceActivityName($0) })
    } else {
      center.stopMonitoring(activityNames(ruleId: ruleId, windowMinutes: 60))
      center.stopMonitoring([activityName(ruleId: ruleId)])
    }

    // 한도 해제 시 해당 규칙 쉴드만 제거하려면 전체 스토어 clear — 규칙별 토큰 추적은 확장에서 처리
    limitStore.shield.applications = nil
    limitStore.shield.applicationCategories = nil
  }

  /// 메인 앱에서 한도 도달 시 즉시 쉴드 (확장 미연결 시 폴백·테스트)
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
#endif
