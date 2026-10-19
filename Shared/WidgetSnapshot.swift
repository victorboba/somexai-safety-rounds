import Foundation

/// Summary the app writes to the App Group for the widget.
struct WidgetSnapshot: Codable {
    var totalAssets: Int = 0
    var overdue: Int = 0
    var dueThisWeek: Int = 0
    var nextDueTag: String? = nil
    var nextDueDate: Date? = nil
    var lastInspectionDate: Date? = nil
    var updatedAt: Date = .now

    static let storageKey = "widget.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults.set(data, forKey: Self.storageKey)
    }

    static let placeholder = WidgetSnapshot(totalAssets: 14, overdue: 2, dueThisWeek: 3, nextDueTag: "EXT-03",
                                            nextDueDate: Calendar.current.date(byAdding: .day, value: 2, to: .now), lastInspectionDate: .now)
}
