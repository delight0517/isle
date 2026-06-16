import Foundation

#if canImport(DeviceActivity) && canImport(FamilyControls)
import DeviceActivity
import FamilyControls

/// 스케줄 슬롯별 DeviceActivity — 확장 `intervalDidStart/End`에서 스냅샷 재동기화.
enum IsleScheduleDeviceActivityBridge {
  private static let registryKey = "isle.schedule.da.registered"

  static func activityName(scheduleId: String, slotIndex: Int, part: Int = 0) -> DeviceActivityName {
    let safeId = scheduleId.replacingOccurrences(of: ":", with: "-")
    let suffix = part == 0 ? "\(slotIndex)" : "\(slotIndex).p\(part)"
    return DeviceActivityName("com.isle.app.schedule.\(safeId).\(suffix)")
  }

  private static func nextWeekday(_ day: Int) -> Int {
    dartWeekdayToCalendar((day + 1) % 7)
  }

  private static func dartWeekdayToCalendar(_ day: Int) -> Int {
    // Dart 0=월 … 6=일 → Calendar 1=일, 2=월
    day == 6 ? 1 : day + 2
  }

  @discardableResult
  static func syncFromSchedulesJson(_ json: String) -> Bool {
    guard AuthorizationCenter.shared.authorizationStatus == .approved else { return false }
    guard let data = json.data(using: .utf8),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let schedules = root["schedules"] as? [[String: Any]]
    else { return false }

    let center = DeviceActivityCenter()
    let previous = IsleAppLimitStorage.defaults?.stringArray(forKey: registryKey) ?? []
    if !previous.isEmpty {
      center.stopMonitoring(previous.map { DeviceActivityName($0) })
    }

    var registered: [String] = []
    for schedule in schedules {
      guard schedule["enabled"] as? Bool ?? true,
            let scheduleId = schedule["id"] as? String,
            let slots = schedule["slots"] as? [[String: Any]]
      else { continue }

      for (index, slot) in slots.enumerated() {
        let day = (slot["day"] as? Int) ?? 0
        let start = (slot["startMinute"] as? Int) ?? 0
        let end = (slot["endMinute"] as? Int) ?? 0
        let weekday = dartWeekdayToCalendar(day)
        let startH = start / 60
        let startM = start % 60
        let endH = end / 60
        let endM = end % 60

        if start <= end {
          let name = activityName(scheduleId: scheduleId, slotIndex: index)
          let scheduleDA = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: startH, minute: startM, weekday: weekday),
            intervalEnd: DateComponents(hour: endH, minute: endM, weekday: weekday),
            repeats: true
          )
          center.stopMonitoring([name])
          if register(center: center, name: name, schedule: scheduleDA) {
            registered.append(name.rawValue)
          }
        } else {
          // 자정 넘김 — part0: start~23:59, part1: 다음날 00:00~end
          let name0 = activityName(scheduleId: scheduleId, slotIndex: index, part: 0)
          let name1 = activityName(scheduleId: scheduleId, slotIndex: index, part: 1)
          let nextWd = nextWeekday(day)
          let part0 = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: startH, minute: startM, weekday: weekday),
            intervalEnd: DateComponents(hour: 23, minute: 59, weekday: weekday),
            repeats: true
          )
          let part1 = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, weekday: nextWd),
            intervalEnd: DateComponents(hour: endH, minute: endM, weekday: nextWd),
            repeats: true
          )
          center.stopMonitoring([name0, name1])
          if register(center: center, name: name0, schedule: part0) {
            registered.append(name0.rawValue)
          }
          if register(center: center, name: name1, schedule: part1) {
            registered.append(name1.rawValue)
          }
        }
      }
    }

    IsleAppLimitStorage.defaults?.set(registered, forKey: registryKey)
    return !registered.isEmpty
  }

  private static func register(
    center: DeviceActivityCenter,
    name: DeviceActivityName,
    schedule: DeviceActivitySchedule
  ) -> Bool {
    do {
      try center.startMonitoring(name, during: schedule)
      return true
    } catch {
      return false
    }
  }

  static func stopAll() {
    let center = DeviceActivityCenter()
    let previous = IsleAppLimitStorage.defaults?.stringArray(forKey: registryKey) ?? []
    if !previous.isEmpty {
      center.stopMonitoring(previous.map { DeviceActivityName($0) })
    }
    IsleAppLimitStorage.defaults?.removeObject(forKey: registryKey)
  }
}
#endif
