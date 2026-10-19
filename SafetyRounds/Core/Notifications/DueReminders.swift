import Foundation
import UserNotifications

/// One local notification per day that has inspections due, for the next 60 days, plus one for anything
/// already overdue. Rescheduled whenever assets or inspections change. Off until the user turns it on in Settings.
enum DueReminders {
    static let enabledKey = "reminders.enabled"
    static let hourKey = "reminders.hour"
    static let prefix = "due."

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var hour: Int { let h = UserDefaults.standard.integer(forKey: hourKey); return h == 0 ? 9 : h }

    static func ensurePermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied: return false
        default: return true
        }
    }

    static func reschedule(assets: [Asset], inspections: [Inspection], now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard isEnabled, await ensurePermission() else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        var byDay: [Date: [String]] = [:]
        var overdueTags: [String] = []
        for asset in assets where asset.isActive {
            let last = DueCalculator.lastInspection(for: asset, in: inspections)
            let due = DueCalculator.nextDue(for: asset, last: last)
            if due <= today {
                overdueTags.append(asset.title)
            } else if let limit = calendar.date(byAdding: .day, value: 60, to: today), due <= limit {
                byDay[due, default: []].append(asset.title)
            }
        }

        func request(id: String, on day: Date, body: String) {
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            let content = UNMutableNotificationContent()
            content.title = AppConfig.appName
            content.body = body
            content.sound = .default
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
        }

        if !overdueTags.isEmpty, let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
            request(id: prefix + "overdue", on: tomorrow, body: "\(overdueTags.count) inspection\(overdueTags.count == 1 ? " is" : "s are") overdue: \(overdueTags.prefix(3).joined(separator: ", "))\(overdueTags.count > 3 ? "…" : "")")
        }
        for (day, tags) in byDay.sorted(by: { $0.key < $1.key }).prefix(30) {
            request(id: prefix + ISO8601DateFormatter().string(from: day), on: day,
                    body: "\(tags.count) inspection\(tags.count == 1 ? "" : "s") due today: \(tags.prefix(3).joined(separator: ", "))\(tags.count > 3 ? "…" : "")")
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
