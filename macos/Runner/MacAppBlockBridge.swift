import Cocoa
import FlutterMacOS

/// Per-schedule / per-rule app blocking — terminate by localized display name.
final class MacAppBlockBridge: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.isle.app/mac_app_block",
      binaryMessenger: registrar.messenger
    )
    let instance = MacAppBlockBridge()
    registrar.addMethodCallDelegate(instance, channel: channel)
    instance.startMonitoring()
  }

  private var targets: [String] = []
  private var monitorTimer: Timer?
  private var launchObserver: NSObjectProtocol?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setTargets":
      let raw = (call.arguments as? [String: Any])?["targets"] as? [String] ?? []
      targets = raw
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty }
      enforceAgainstRunningApps()
      result(true)
    case "getStatus":
      result([
        "targetCount": targets.count,
        "targets": targets,
        "monitorRunning": monitorTimer != nil,
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startMonitoring() {
    if launchObserver == nil {
      launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didLaunchApplicationNotification,
        object: nil,
        queue: .main
      ) { [weak self] note in
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
          return
        }
        self?.enforce(app: app)
      }
    }
    if monitorTimer == nil {
      monitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
        self?.enforceAgainstRunningApps()
      }
    }
  }

  private func enforceAgainstRunningApps() {
    guard !targets.isEmpty else { return }
    for app in NSWorkspace.shared.runningApplications {
      enforce(app: app)
    }
  }

  private func enforce(app: NSRunningApplication) {
    if app.bundleIdentifier == Bundle.main.bundleIdentifier { return }
    guard let raw = app.localizedName, !raw.isEmpty else { return }
    let name = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !name.isEmpty else { return }

    let blocked = targets.contains { target in
      if name == target { return true }
      if target.count < 5 { return false }
      return name.contains(target)
    }
    if !blocked { return }
    _ = app.terminate() || app.forceTerminate()
  }
}
