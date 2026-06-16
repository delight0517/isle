import Cocoa
import FlutterMacOS

/// Safari·Chrome 등 브라우저가 전면일 때만 초 단위 누적 [Volt: Isle 실행 중·5초 tick]
final class MacBrowserSessionMonitor {
  static let shared = MacBrowserSessionMonitor()

  private let trackedBundles: Set<String> = [
    "com.apple.Safari",
    "com.google.Chrome",
    "com.brave.Browser",
    "com.microsoft.edgemac",
    "company.thebrowser.Browser", // Arc
  ]

  private let storageKey = "mac_browser_seconds"
  private let dayKey = "mac_browser_day"
  private var timer: Timer?
  private var observer: NSObjectProtocol?

  private var defaults: UserDefaults? {
    UserDefaults(suiteName: "group.com.isle.app") ?? .standard
  }

  func isRunning() -> Bool { timer != nil }

  func start() {
    guard timer == nil else { return }
    _ensureToday()
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?._tick()
    }
    timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
      self?._tick()
    }
    if let timer { RunLoop.main.add(timer, forMode: .common) }
    _tick()
  }

  func stop() {
    if let observer {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
      self.observer = nil
    }
    timer?.invalidate()
    timer = nil
  }

  func secondsToday() -> Int {
    _ensureToday()
    return defaults?.integer(forKey: storageKey) ?? 0
  }

  func frontBrowserBundleId() -> String? {
    guard let bundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
          trackedBundles.contains(bundle)
    else { return nil }
    return bundle
  }

  private func _todayString() -> String {
    let n = Date()
    return String(format: "%04d-%02d-%02d", n.year, n.month, n.day)
  }

  private func _ensureToday() {
    let today = _todayString()
    if defaults?.string(forKey: dayKey) != today {
      defaults?.set(today, forKey: dayKey)
      defaults?.set(0, forKey: storageKey)
    }
  }

  private func _tick() {
    _ensureToday()
    guard let bundle = frontBrowserBundleId() else { return }
    _ = bundle
    let next = secondsToday() + 5
    defaults?.set(next, forKey: storageKey)
  }
}

final class MacBrowserSessionPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.isle.app/mac_browser",
      binaryMessenger: registrar.messenger
    )
    let instance = MacBrowserSessionPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let mon = MacBrowserSessionMonitor.shared
    switch call.method {
    case "isSupported":
      result(true)
    case "startMonitoring":
      mon.start()
      result(true)
    case "stopMonitoring":
      mon.stop()
      result(nil)
    case "isMonitoring":
      result(mon.isRunning())
    case "browserSecondsToday":
      result(mon.secondsToday())
    case "browserMinutesToday":
      result(mon.secondsToday() / 60)
    case "frontBrowserBundleId":
      result(mon.frontBrowserBundleId())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private extension Date {
  var year: Int { Calendar.current.component(.year, from: self) }
  var month: Int { Calendar.current.component(.month, from: self) }
  var day: Int { Calendar.current.component(.day, from: self) }
}
