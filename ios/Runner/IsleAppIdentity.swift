import Foundation

/// Info.plist `AppGroupId` 단일 출처 — Runner·확장 타깃 공통.
enum IsleAppIdentity {
  static let appGroupId: String = {
    if let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String,
       !id.isEmpty {
      return id
    }
    return "group.com.isle.app.moa"
  }()
}
