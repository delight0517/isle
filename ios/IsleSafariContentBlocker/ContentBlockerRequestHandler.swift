import Foundation
import SafariServices

/// Safari Content Blocker — App Group `content_blocker_v1.json` (Isle rules export).
class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
  private static let appGroupId: String = {
    if let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String, !id.isEmpty {
      return id
    }
    return "group.com.isle.app.moa"
  }()
  private static let fileName = "content_blocker_v1.json"

  func beginRequest(with context: NSExtensionContext) {
    let url = Self.blockerFileURL() ?? Bundle.main.url(forResource: "blockerList", withExtension: "json")
    guard let fileURL = url else {
      context.cancelRequest(withError: NSError(domain: "IsleSafariBlocker", code: 1))
      return
    }
    let attachment = NSItemProvider(contentsOf: fileURL)!
    let item = NSExtensionItem()
    item.attachments = [attachment]
    context.completeRequest(returningItems: [item])
  }

  private static func blockerFileURL() -> URL? {
    guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
      return nil
    }
    let url = dir.appendingPathComponent(fileName)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }
}
