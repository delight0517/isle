import Flutter
import SwiftUI
import UIKit

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(FamilyControls)
private struct IsleScreenTimeLabelsRow: View {
  let selection: FamilyActivitySelection
  let maxCount: Int

  var body: some View {
    let appTokens = Array(selection.applicationTokens)
    let catTokens = Array(selection.categoryTokens)
    let shownApps = min(appTokens.count, maxCount)
    let shownCats = min(catTokens.count, max(0, maxCount - shownApps))
    let total = appTokens.count + catTokens.count
    let overflow = max(0, total - maxCount)

    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(0..<shownApps, id: \.self) { i in
          Label(appTokens[i])
            .labelStyle(.iconOnly)
            .font(.caption)
        }
        ForEach(0..<shownCats, id: \.self) { i in
          Label(catTokens[i])
            .labelStyle(.iconOnly)
            .font(.caption)
        }
        if overflow > 0 {
          Text("+\(overflow)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 2)
    }
  }
}

private class IsleScreenTimeLabelsPlatformView: NSObject, FlutterPlatformView {
  private let hosting: UIHostingController<IsleScreenTimeLabelsRow>

  init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) {
    var selection = FamilyActivitySelection()
    let params = args as? [String: Any]
    let encoded = params?["encoded"] as? String ?? ""
    let maxCount = (params?["maxCount"] as? Int) ?? 10

    if let data = Data(base64Encoded: encoded),
       let decoded = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
      selection = decoded
    }

    hosting = UIHostingController(
      rootView: IsleScreenTimeLabelsRow(selection: selection, maxCount: maxCount)
    )
    hosting.view.backgroundColor = .clear
    hosting.view.frame = frame
    super.init()
  }

  func view() -> UIView {
    hosting.view
  }
}

class IsleScreenTimeLabelsViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    IsleScreenTimeLabelsPlatformView(frame: frame, viewIdentifier: viewId, arguments: args)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}
#endif
