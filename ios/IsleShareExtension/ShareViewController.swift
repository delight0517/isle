import Social
import UIKit
import UniformTypeIdentifiers

// receive_sharing_intent 플러그인과 동일 키 — Runner(Flutter)가 읽음
private let kSchemePrefix = "ShareMedia"
private let kUserDefaultsKey = "ShareKey"
private let kUserDefaultsMessageKey = "ShareMessageKey"
private let kAppGroupIdKey = "AppGroupId"

private struct SharedMediaFile: Codable {
  let path: String
  let mimeType: String?
  let type: String
}

/// iOS 공유 시트 → Isle (pod 없이 Extension-safe 구현)
final class ShareViewController: SLComposeServiceViewController {
  private var hostAppBundleIdentifier = ""
  private var appGroupId = ""
  private var sharedMedia: [SharedMediaFile] = []

  override func isContentValid() -> Bool { true }

  override func viewDidLoad() {
    super.viewDidLoad()
    loadIds()
  }

  override func didSelectPost() {
    saveAndRedirect(message: contentText)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
          let attachments = item.attachments else {
      saveAndRedirect(message: contentText)
      return
    }

    if attachments.isEmpty {
      saveAndRedirect(message: contentText)
      return
    }

    let group = DispatchGroup()
    for attachment in attachments {
      if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
        group.enter()
        attachment.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, _ in
          defer { group.leave() }
          guard let self, let url = data as? URL else { return }
          self.sharedMedia.append(
            SharedMediaFile(path: url.absoluteString, mimeType: nil, type: "url"),
          )
        }
      } else if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
        group.enter()
        attachment.loadItem(forTypeIdentifier: UTType.text.identifier) { [weak self] data, _ in
          defer { group.leave() }
          guard let self, let text = data as? String else { return }
          self.sharedMedia.append(
            SharedMediaFile(path: text, mimeType: "text/plain", type: "text"),
          )
        }
      } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
        group.enter()
        attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] data, _ in
          defer { group.leave() }
          guard let self, let text = data as? String else { return }
          self.sharedMedia.append(
            SharedMediaFile(path: text, mimeType: "text/plain", type: "text"),
          )
        }
      }
    }

    group.notify(queue: .main) { [weak self] in
      self?.saveAndRedirect(message: self?.contentText)
    }
  }

  override func configurationItems() -> [Any]! { [] }

  private func loadIds() {
    let extId = Bundle.main.bundleIdentifier ?? ""
    if let dot = extId.lastIndex(of: ".") {
      hostAppBundleIdentifier = String(extId[..<dot])
    }
    appGroupId = (Bundle.main.object(forInfoDictionaryKey: kAppGroupIdKey) as? String)
      ?? "group.\(hostAppBundleIdentifier)"
  }

  private func saveAndRedirect(message: String?) {
    let defaults = UserDefaults(suiteName: appGroupId)
    if let data = try? JSONEncoder().encode(sharedMedia) {
      defaults?.set(data, forKey: kUserDefaultsKey)
    }
    defaults?.set(message, forKey: kUserDefaultsMessageKey)
    defaults?.synchronize()
    redirectToHostApp()
  }

  private func redirectToHostApp() {
    loadIds()
    guard let url = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):share") else {
      extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
      return
    }
    var responder: UIResponder? = self
    if #available(iOS 18.0, *) {
      while let r = responder {
        if let app = r as? UIApplication {
          app.open(url, options: [:], completionHandler: nil)
          break
        }
        responder = r.next
      }
    } else {
      let sel = sel_registerName("openURL:")
      while let r = responder {
        if r.responds(to: sel) {
          _ = r.perform(sel, with: url)
          break
        }
        responder = r.next
      }
    }
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }
}
