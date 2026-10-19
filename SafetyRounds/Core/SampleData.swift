import Foundation
import SwiftData

#if DEBUG
/// Debug-only sample data: two sites, a dozen assets, six months of monthly checks with a couple of
/// misses and one failure, and service dates coming up. Clearly fictional.
enum SampleData {
    static func insert(into context: ModelContext) {
        let calendar = Calendar.current
        let main = Site(name: "Riverside Community Center", address: "410 Mill St")
        let annex = Site(name: "Gym Annex")
        context.insert(main)
        context.insert(annex)

        func asset(_ site: Site, _ type: EquipmentType, _ tag: String, _ location: String, details: String = "", expiries: [Int?] = []) -> Asset {
            let a = Asset(site: site, type: type, tag: tag, location: location)
            a.details = details
            a.createdAt = calendar.date(byAdding: .month, value: -7, to: .now) ?? .now
            a.expiries = expiries.map { $0.flatMap { calendar.date(byAdding: .day, value: $0, to: .now) } }
            context.insert(a)
            return a
        }

        // (asset, days since the last check, checklist line that failed on the last check)
        let assets: [(Asset, daysSinceLast: Int, failedLast: String?)] = [
            (asset(main, .extinguisher, "EXT-01", "Lobby, by front doors", details: "10 lb ABC, Amerex B456", expiries: [20, 700, 1500]), 25, nil),
            (asset(main, .extinguisher, "EXT-02", "Kitchen, left of back door", details: "6 L wet chemical (K)", expiries: [140]), 27, nil),
            (asset(main, .extinguisher, "EXT-03", "Boiler room", details: "10 lb ABC", expiries: [-5]), 62, nil),
            (asset(main, .extinguisher, "EXT-04", "Hallway B, near restrooms", details: "5 lb ABC", expiries: [200]), 12, nil),
            (asset(main, .aed, "AED-01", "Lobby wall cabinet", details: "Philips HeartStart OnSite", expiries: [45, 400]), 28, nil),
            (asset(main, .emergencyLight, "EL-01", "Stairwell A, landing", expiries: [90]), 10, nil),
            (asset(main, .emergencyLight, "EL-02", "Stairwell B, top", expiries: [90]), 22, "30-second test: lamps light on battery"),
            (asset(main, .exitSign, "EXIT-01", "Above main exit", expiries: [90]), 15, nil),
            (asset(main, .pullStation, "PS-01", "Lobby, beside AED"), 45, nil),
            (asset(main, .firstAidKit, "FAK-01", "Front desk", expiries: [60]), 3, nil),
            (asset(annex, .extinguisher, "EXT-05", "Gym, east wall", details: "10 lb ABC", expiries: [300]), 8, nil),
            (asset(annex, .eyewash, "EW-01", "Pool chemical room", expiries: [120]), 5, nil),
            (asset(annex, .emergencyLight, "EL-03", "Gym, over exit", expiries: [90]), 29, nil),
        ]

        for (a, daysSinceLast, failedLast) in assets {
            let step = a.intervalDays
            let count = a.type == .eyewash ? 12 : 6
            for n in 0..<count {
                guard let day = calendar.date(byAdding: .day, value: -(daysSinceLast + n * step), to: .now),
                      let time = calendar.date(bySettingHour: 9, minute: 15 + Int.random(in: 0...40), second: 0, of: day) else { continue }
                let i = Inspection(asset: a, date: time, inspector: "D. Alvarez")
                if n == 0, let failedLast { i.failedItems = [failedLast]; i.notes = "Lamp out on the left side. Work order placed." }
                context.insert(i)
            }
        }
    }
}
#endif
