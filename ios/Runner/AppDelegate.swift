import AVFoundation
import BackgroundTasks
import Flutter
import UIKit
import AuthenticationServices

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WebSessionBridgePlugin") {
      WebSessionBridgePlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WebContentRuleBridgePlugin") {
      WebContentRuleBridgePlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BlueCloudAuthPlugin") {
      BlueCloudAuthPlugin.register(with: registrar)
    }
  }
}

/// Opens Brainwire's first-party BlueCloud sign-in in the system auth session.
/// The token returns through ASWebAuthenticationSession instead of being broadcast
/// to any app that registers the shared `moa://` URL scheme.
final class BlueCloudAuthPlugin: NSObject, FlutterPlugin, ASWebAuthenticationPresentationContextProviding {
  private var session: ASWebAuthenticationSession?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.isle.app/bluecloud_auth", binaryMessenger: registrar.messenger())
    let instance = BlueCloudAuthPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "signIn" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let rawUrl = args["url"] as? String,
          let url = URL(string: rawUrl),
          url.scheme == "https",
          url.host == "brainwire-f2gf.onrender.com",
          url.path == "/cloud.html" else {
      result(FlutterError(code: "invalid_request", message: "BlueCloud sign-in URL is invalid.", details: nil))
      return
    }

    let authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "moa") { [weak self] callback, error in
      self?.session = nil
      if let error {
        let code = (error as NSError).code == 1 ? "cancelled" : "auth_failed"
        result(FlutterError(code: code, message: "BlueCloud sign-in did not complete.", details: nil))
        return
      }
      guard let callback,
            callback.scheme == "moa",
            callback.host == "auth",
            let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false),
            let token = parts.queryItems?.first(where: { $0.name == "token" })?.value,
            !token.isEmpty else {
        result(FlutterError(code: "invalid_callback", message: "BlueCloud returned an invalid sign-in response.", details: nil))
        return
      }
      result(["token": token])
    }
    authSession.presentationContextProvider = self
    authSession.prefersEphemeralWebBrowserSession = false
    session = authSession
    if !authSession.start() {
      session = nil
      result(FlutterError(code: "auth_unavailable", message: "Could not open the system sign-in session.", details: nil))
    }
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow) ?? UIWindow()
  }
}
