import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    let minSize = NSSize(width: 960, height: 720)
    self.minSize = minSize
    var frame = windowFrame
    if frame.width < minSize.width || frame.height < minSize.height {
      frame = NSRect(x: frame.origin.x, y: frame.origin.y, width: minSize.width, height: minSize.height)
    }
    self.setFrame(frame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    MacScreenTimeBridgePlugin.register(with: flutterViewController.registrar(forPlugin: "MacScreenTimeBridgePlugin"))
    MacAppLimitPlugin.register(with: flutterViewController.registrar(forPlugin: "MacAppLimitPlugin"))
    MacBrowserSessionPlugin.register(with: flutterViewController.registrar(forPlugin: "MacBrowserSessionPlugin"))
    MacAppBlockBridge.register(with: flutterViewController.registrar(forPlugin: "MacAppBlockBridge"))

    super.awakeFromNib()
  }
}
