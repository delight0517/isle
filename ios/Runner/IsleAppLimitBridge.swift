import Foundation

#if canImport(FamilyControls)
import DeviceActivity
import FamilyControls
import ManagedSettings
#endif

enum IsleAppLimitStorage {
  static let appGroupId = IsleAppIdentity.appGroupId
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
  /// iOS DeviceActivity 동시 모니터 상한(문서·실측 ~20).
  private static let deviceActivityMonitorBudget = 20
  private static var legacyMonitorsCleaned = false
  /// 진단 — 마지막 registerLimit 실패 사유 (빈 문자열 = 성공/미실행).
  private(set) static var lastFailureReason = ""

  private struct HourlyMonitorPlan {
    let hour: Int
    let durationHours: Int
    let weekday: Int?
    let thresholdMinutes: Int
  }

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

  static func eventName(ruleId: String, suffix: String = "main") -> DeviceActivityEvent.Name {
    let safe = ruleId.replacingOccurrences(of: ":", with: "-")
    return DeviceActivityEvent.Name("com.isle.app.limit.event.\(safe).\(suffix)")
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

  private static func hourlyActivityName(
    ruleId: String,
    hour: Int,
    weekday: Int? = nil
  ) -> DeviceActivityName {
    let safe = ruleId.replacingOccurrences(of: ":", with: "-")
    if let weekday {
      return DeviceActivityName("com.isle.app.limit.\(safe).h\(hour).wd\(weekday)")
    }
    return DeviceActivityName("com.isle.app.limit.\(safe).h\(hour)")
  }

  /// 슬롯이 7일 모두 하루 종일(0~1440)이면 요일별 모니터 불필요.
  private static func isFullWeekAllDay(slots: [[String: Any]]) -> Bool {
    guard slots.count >= 7 else { return false }
    var covered = Set<Int>()
    for slot in slots {
      let day = (slot["day"] as? Int) ?? -1
      guard (0..<7).contains(day) else { continue }
      let start = (slot["startMinute"] as? Int) ?? -1
      let end = (slot["endMinute"] as? Int) ?? -1
      if start == 0 && end >= 1440 { covered.insert(day) }
    }
    return covered.count == 7
  }

  private static func daysInSlotForHour(hour: Int, slots: [[String: Any]]) -> [Int] {
    (0..<7).filter { hourInSlot(day: $0, hour: hour, slots: slots) }
  }

  private static func shouldMonitorHour(
    hour: Int,
    inSlot: Bool,
    slots: [[String: Any]]
  ) -> Bool {
    let daysInside = daysInSlotForHour(hour: hour, slots: slots)
    if inSlot { return !daysInside.isEmpty }
    return daysInside.count < 7
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
    lastFailureReason = ""

    guard AuthorizationCenter.shared.authorizationStatus == .approved else {
      lastFailureReason = "not_authorized(\(AuthorizationCenter.shared.authorizationStatus.rawValue))"
      return false
    }
    guard minutes > 0 else { lastFailureReason = "minutes<=0"; return false }
    guard let data = Data(base64Encoded: encoded) else {
      lastFailureReason = "base64_decode_failed"; return false
    }
    guard let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
      lastFailureReason = "plist_decode_failed"; return false
    }
    guard !selection.applicationTokens.isEmpty else {
      lastFailureReason = "no_app_tokens(cats=\(selection.categoryTokens.count),webs=\(selection.webDomainTokens.count))"
      return false
    }

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

  /// 매시간 N분 한도 — 시간당 1개·일일 반복 모니터 (요일별 중복 등록 금지).
  private static func registerHourlyWindowLimits(
    ruleId: String,
    minutes: Int,
    encoded: String,
    label: String,
    interventionTitle: String,
    interventionBody: String,
    scope: String,
    slots: [[String: Any]]?,
    selection: FamilyActivitySelection
  ) -> Bool {
    let scoped = scope != "always"
    let slotList = slots ?? []
    let inSlot = scope == "in_slot"
    let center = DeviceActivityCenter()
    var registered: [String] = []

    let fullWeekAllDay = scoped && !slotList.isEmpty && isFullWeekAllDay(slots: slotList)

    var plans: [HourlyMonitorPlan] = []
    for hour in 0..<24 {
      if scoped && !slotList.isEmpty && !fullWeekAllDay {
        guard shouldMonitorHour(hour: hour, inSlot: inSlot, slots: slotList) else { continue }
        let daysInside = daysInSlotForHour(hour: hour, slots: slotList)
        let targetWeekdays: [Int?]
        if inSlot {
          targetWeekdays = daysInside.count == 7 ? [nil] : daysInside.map { dartWeekdayToCalendar($0) }
        } else {
          let daysOutside = (0..<7).filter { !daysInside.contains($0) }
          guard !daysOutside.isEmpty else { continue }
          targetWeekdays = daysOutside.count == 7 ? [nil] : daysOutside.map { dartWeekdayToCalendar($0) }
        }
        for weekday in targetWeekdays {
          plans.append(HourlyMonitorPlan(hour: hour, durationHours: 1, weekday: weekday, thresholdMinutes: minutes))
        }
        continue
      }

      if scoped && fullWeekAllDay && !inSlot { continue }

      plans.append(HourlyMonitorPlan(hour: hour, durationHours: 1, weekday: nil, thresholdMinutes: minutes))
    }

    plans = compactPlansToBudget(plans, perHourMinutes: minutes)
    let existingElsewhere = monitorCountExcluding(ruleId: ruleId)
    let budgetLeft = max(1, deviceActivityMonitorBudget - existingElsewhere)
    if plans.count > budgetLeft {
      plans = Array(plans.prefix(budgetLeft))
    }
    guard !plans.isEmpty else { lastFailureReason = "no_plans(scope=\(scope))"; return false }

    for plan in plans {
      let suffix = plan.weekday.map { "h\(plan.hour).wd\($0)" } ?? "h\(plan.hour)"
      let name = hourlyActivityName(ruleId: ruleId, hour: plan.hour, weekday: plan.weekday)
      let ev = eventName(ruleId: ruleId, suffix: suffix)
      if startHourlyMonitor(
        center: center,
        name: name,
        hour: plan.hour,
        durationHours: plan.durationHours,
        weekday: plan.weekday,
        thresholdMinutes: plan.thresholdMinutes,
        selection: selection,
        ev: ev,
        registered: &registered
      ) {
        continue
      }
    }

    guard !registered.isEmpty else {
      // 시간별 모니터가 예산 초과/충돌로 전부 실패 → 단일 일일 모니터로 폴백.
      // (한도가 아예 안 걸리는 것보다, 하루 한도라도 확실히 거는 게 낫다.)
      lastFailureReason = "hourly_failed_fellback_daily(plans=\(plans.count),existing=\(existingElsewhere))"
      return registerSingleDailyMonitor(
        ruleId: ruleId,
        minutes: minutes,
        encoded: encoded,
        label: label,
        interventionTitle: interventionTitle,
        interventionBody: interventionBody,
        scope: scope,
        selection: selection
      )
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
    return true
  }

  /// 단일 일일 모니터(00:00–23:59 반복) — 시간별 모니터가 예산 초과로 실패할 때 폴백.
  /// 모니터 1개라 다른 스케줄과 합쳐도 iOS 상한을 넘지 않음 → 등록 보장.
  private static func registerSingleDailyMonitor(
    ruleId: String,
    minutes: Int,
    encoded: String,
    label: String,
    interventionTitle: String,
    interventionBody: String,
    scope: String,
    selection: FamilyActivitySelection
  ) -> Bool {
    let center = DeviceActivityCenter()
    let name = activityName(ruleId: ruleId)
    let ev = eventName(ruleId: ruleId, suffix: "dailyfallback")
    let event = makeThresholdEvent(selection: selection, minutes: minutes)
    let schedule = DeviceActivitySchedule(
      intervalStart: DateComponents(hour: 0, minute: 0),
      intervalEnd: DateComponents(hour: 23, minute: 59),
      repeats: true
    )
    do {
      try center.startMonitoring(name, during: schedule, events: [ev: event])
    } catch {
      lastFailureReason = "daily_fallback_threw(\(error.localizedDescription))"
      return false
    }
    var registry = IsleAppLimitStorage.loadRegistry().filter { ($0["id"] as? String) != ruleId }
    registry.append([
      "id": ruleId,
      "minutes": minutes,
      "windowMinutes": 1440,
      "encoded": encoded,
      "label": label,
      "interventionTitle": interventionTitle,
      "interventionBody": interventionBody,
      "scope": "\(scope)_daily_fallback",
      "activityNames": [name.rawValue],
    ])
    IsleAppLimitStorage.saveRegistry(registry)
    return true
  }

  /// 24시간 한도는 12개(2시간 블록)로 압축 — OS 모니터 예산·다른 스케줄과 공유.
  private static func compactPlansToBudget(
    _ plans: [HourlyMonitorPlan],
    perHourMinutes: Int
  ) -> [HourlyMonitorPlan] {
    let dailyHours = plans.filter { $0.weekday == nil && $0.durationHours == 1 }.map(\.hour).sorted()
    if dailyHours.count >= 24 {
      return stride(from: 0, to: 24, by: 2).map { h in
        HourlyMonitorPlan(
          hour: h,
          durationHours: 2,
          weekday: nil,
          thresholdMinutes: max(1, perHourMinutes * 2)
        )
      }
    }

    guard plans.count > deviceActivityMonitorBudget else { return plans }

    var buckets: [Int?: Set<Int>] = [:]
    for plan in plans where plan.durationHours == 1 {
      buckets[plan.weekday, default: []].insert(plan.hour)
    }

    var merged: [HourlyMonitorPlan] = []
    for weekday in buckets.keys {
      let hours = buckets[weekday]!.sorted()
      let chunkSize = hours.count > deviceActivityMonitorBudget ? 2 : 1
      var idx = 0
      while idx < hours.count {
        let h = hours[idx]
        merged.append(
          HourlyMonitorPlan(
            hour: h,
            durationHours: chunkSize,
            weekday: weekday,
            thresholdMinutes: max(1, perHourMinutes * chunkSize)
          )
        )
        idx += chunkSize
      }
    }

    merged.sort { ($0.weekday ?? -1, $0.hour) < ($1.weekday ?? -1, $1.hour) }
    if merged.count > deviceActivityMonitorBudget {
      return Array(merged.prefix(deviceActivityMonitorBudget))
    }
    return merged
  }

  /// 예산 계산은 **실제 OS 활성 모니터** 기준 — 불용 레지스트리 누적이
  /// 예산을 갉아먹어 새 규칙(카카오·인스타 등) 등록이 굶어 죽는 것을 방지.
  private static func monitorCountExcluding(ruleId: String) -> Int {
    let safe = ruleId.replacingOccurrences(of: ":", with: "-")
    let mine = "com.isle.app.limit.\(safe)"
    return DeviceActivityCenter().activities
      .filter { !$0.rawValue.hasPrefix(mine) }
      .count
  }

  private static func stopLegacyDayHourMonitorsIfNeeded(center: DeviceActivityCenter, ruleId: String) {
    guard !legacyMonitorsCleaned else { return }
    legacyMonitorsCleaned = true
    let safe = ruleId.replacingOccurrences(of: ":", with: "-")
    var legacy: [DeviceActivityName] = []
    for day in 0..<7 {
      for hour in 0..<24 {
        legacy.append(DeviceActivityName("com.isle.app.limit.\(safe).d\(day).h\(hour)"))
      }
    }
    center.stopMonitoring(legacy)
  }

  private static func startHourlyMonitor(
    center: DeviceActivityCenter,
    name: DeviceActivityName,
    hour: Int,
    durationHours: Int,
    weekday: Int?,
    thresholdMinutes: Int,
    selection: FamilyActivitySelection,
    ev: DeviceActivityEvent.Name,
    registered: inout [String]
  ) -> Bool {
    var start = DateComponents(hour: hour, minute: 0)
    let endHour = (hour + durationHours) % 24
    var end = DateComponents(hour: endHour, minute: 0)
    if let weekday {
      start.weekday = weekday
      end.weekday = weekday
    }
    let schedule = DeviceActivitySchedule(
      intervalStart: start,
      intervalEnd: end,
      repeats: true
    )
    let event = makeThresholdEvent(selection: selection, minutes: thresholdMinutes)
    do {
      try center.startMonitoring(name, during: schedule, events: [ev: event])
      registered.append(name.rawValue)
      return true
    } catch {
      return false
    }
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
    if windowMinutes == 60 {
      return registerHourlyWindowLimits(
        ruleId: ruleId,
        minutes: minutes,
        encoded: encoded,
        label: label,
        interventionTitle: interventionTitle,
        interventionBody: interventionBody,
        scope: "always",
        slots: nil,
        selection: selection
      )
    }

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
    let ev = eventName(ruleId: ruleId, suffix: "daily")

    let schedule = DeviceActivitySchedule(
      intervalStart: DateComponents(hour: 0, minute: 0),
      intervalEnd: DateComponents(hour: 23, minute: 59),
      repeats: true
    )
    do {
      try center.startMonitoring(names[0], during: schedule, events: [ev: event])
      return true
    } catch {
      lastFailureReason = "daily_monitor_threw(\(error.localizedDescription))"
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
    return registerHourlyWindowLimits(
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
    stopLegacyDayHourMonitorsIfNeeded(center: center, ruleId: ruleId)
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
