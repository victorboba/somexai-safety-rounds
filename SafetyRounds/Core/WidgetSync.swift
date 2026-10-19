import Foundation
import WidgetKit

enum WidgetSync {
    static func update(assets: [Asset], inspections: [Inspection]) {
        var snapshot = WidgetSnapshot()
        let active = assets.filter(\.isActive)
        snapshot.totalAssets = active.count
        var nextDue: (tag: String, date: Date)?
        for asset in active {
            let last = DueCalculator.lastInspection(for: asset, in: inspections)
            switch DueCalculator.state(for: asset, last: last) {
            case .neverInspected, .overdue: snapshot.overdue += 1
            case .dueSoon: snapshot.dueThisWeek += 1
            case .ok: break
            }
            let due = DueCalculator.nextDue(for: asset, last: last)
            if due >= Calendar.current.startOfDay(for: .now), nextDue == nil || due < nextDue!.date {
                nextDue = (asset.title, due)
            }
        }
        snapshot.nextDueTag = nextDue?.tag
        snapshot.nextDueDate = nextDue?.date
        snapshot.lastInspectionDate = inspections.map(\.date).max()
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
