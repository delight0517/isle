import AVFoundation
import BackgroundTasks
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    ScheduleSyncRunner.registerBackgroundTask()
    // WebView(Instagram·YouTube) 영상 소리 — 무음 모드에서도 재생 허용
    try? AVAudioSession.sharedInstance().setCategory(
      .playback,
      mode: .default,
      options: [.mixWithOthers]
    )
    try? AVAudioSession.sharedInstance().setActive(true)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    ScheduleSyncRunner.scheduleBackgroundRefresh()
    super.applicationDidEnterBackground(application)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScreenTimeBridgePlugin") {
      ScreenTimeBridgePlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppLimitPlugin") {
      AppLimitPlugin.register(with: registrar)
    }
  }
}
