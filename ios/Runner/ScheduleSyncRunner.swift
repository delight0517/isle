import BackgroundTasks
import Foundation

/// BGAppRefresh — 앱이 백그라운드일 때 스냅샷 기준 Screen Time 재동기화.
enum ScheduleSyncRunner {
  static let taskIdentifier = "com.isle.app.scheduleSync"

  static func registerBackgroundTask() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
      guard let refresh = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }
      handle(refresh)
    }
  }

  static func scheduleBackgroundRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      // 시뮬레이터·권한 없음 등 — 무시
    }
  }

  private static func handle(_ task: BGAppRefreshTask) {
    scheduleBackgroundRefresh()
    let work = DispatchWorkItem {
      _ = IsleScheduleShieldSync.syncFromSnapshotFile()
    }
    task.expirationHandler = { work.cancel() }
    DispatchQueue.global(qos: .utility).async(execute: work)
    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 25) {
      task.setTaskCompleted(success: !work.isCancelled)
    }
  }
}
