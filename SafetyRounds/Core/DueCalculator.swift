import Foundation

enum DueState: Equatable {
    case neverInspected
    case overdue(days: Int)
    case dueSoon(days: Int)
    case ok(days: Int)

    var isActionable: Bool {
        switch self {
        case .neverInspected, .overdue, .dueSoon: true
        case .ok: false
        }
    }
}

/// Pure due-date rules so they can be unit-tested and shared by the list, widget, reminders and report.
enum DueCalculator {
    static func lastInspection(for asset: Asset, in inspections: [Inspection]) -> Inspection? {
        inspections.filter { $0.assetID == asset.id }.max { $0.date < $1.date }
    }

    /// The day the next check is due: last inspection + interval, or the day the asset was added.
    static func nextDue(for asset: Asset, last: Inspection?, calendar: Calendar = .current) -> Date {
        let base = last.map { calendar.date(byAdding: .day, value: asset.intervalDays, to: $0.date) ?? $0.date } ?? asset.createdAt
        return calendar.startOfDay(for: base)
    }

    static func state(for asset: Asset, last: Inspection?, now: Date = .now,
                      soonWindow: Int = AppConfig.dueSoonWindowDays, calendar: Calendar = .current) -> DueState {
        guard let last else { return .neverInspected }
        let due = nextDue(for: asset, last: last, calendar: calendar)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: due).day ?? 0
        if days < 0 { return .overdue(days: -days) }
        if days <= soonWindow { return .dueSoon(days: days) }
        return .ok(days: days)
    }

    /// Dated service items due within `window` days (or already past).
    static func expiringItems(for asset: Asset, within window: Int = AppConfig.expiryWarningDays,
                              now: Date = .now, calendar: Calendar = .current) -> [(label: String, date: Date, days: Int)] {
        asset.datedItems.compactMap { label, date in
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
            return days <= window ? (label, date, days) : nil
        }
    }

    struct Summary: Equatable {
        var assets = 0
        var neverInspected = 0
        var overdue = 0
        var dueSoon = 0
        var inspectionsInPeriod = 0
        var failuresInPeriod = 0
        var expiringSoon = 0
    }

    static func summary(assets: [Asset], inspections: [Inspection], from start: Date, now: Date = .now) -> Summary {
        var s = Summary()
        s.assets = assets.count
        for asset in assets {
            switch state(for: asset, last: lastInspection(for: asset, in: inspections), now: now) {
            case .neverInspected: s.neverInspected += 1
            case .overdue: s.overdue += 1
            case .dueSoon: s.dueSoon += 1
            case .ok: break
            }
            s.expiringSoon += expiringItems(for: asset, now: now).count
        }
        let ids = Set(assets.map(\.id))
        let period = inspections.filter { ids.contains($0.assetID) && $0.date >= start && $0.date <= now }
        s.inspectionsInPeriod = period.count
        s.failuresInPeriod = period.filter { !$0.passed }.count
        return s
    }
}
