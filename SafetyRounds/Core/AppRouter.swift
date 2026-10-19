import Foundation
import Observation

/// Cross-screen navigation requests: a scanned or deep-linked asset to inspect, a tab to show.
@Observable
final class AppRouter {
    enum Tab: Hashable { case due, equipment, report }

    var selectedTab: Tab = .due
    /// Set when a QR label is scanned (in-app or by the Camera app); DueView presents the checklist.
    var pendingAssetID: UUID?

    /// safetyrounds://asset/<uuid>
    func handle(_ url: URL) {
        guard url.scheme == AppConfig.urlScheme, url.host == "asset",
              let id = UUID(uuidString: url.lastPathComponent) else { return }
        pendingAssetID = id
        selectedTab = .due
    }
}
