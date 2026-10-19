import Foundation
import SwiftData

/// One piece of equipment: a specific extinguisher on a specific wall.
@Model
final class Asset {
    var id: UUID = UUID()
    var siteID: UUID = UUID()
    var typeRaw: String = EquipmentType.extinguisher.rawValue
    /// Short label printed on the QR sticker: "EXT-01".
    var tag: String = ""
    /// Where it hangs: "Kitchen, left of the back door".
    var location: String = ""
    /// Free text: "10 lb ABC, Amerex B456, mfg 2021".
    var details: String = ""
    var intervalDays: Int = 30
    var expiry1: Date? = nil
    var expiry2: Date? = nil
    var expiry3: Date? = nil
    var notes: String = ""
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(site: Site, type: EquipmentType, tag: String, location: String = "") {
        self.siteID = site.id
        self.typeRaw = type.rawValue
        self.tag = tag
        self.location = location
        self.intervalDays = type.defaultIntervalDays
    }

    var type: EquipmentType {
        get { EquipmentType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var expiries: [Date?] {
        get { [expiry1, expiry2, expiry3] }
        set {
            expiry1 = newValue.count > 0 ? newValue[0] : nil
            expiry2 = newValue.count > 1 ? newValue[1] : nil
            expiry3 = newValue.count > 2 ? newValue[2] : nil
        }
    }

    /// Labelled expiry dates that are set, in the order the type defines them.
    var datedItems: [(label: String, date: Date)] {
        zip(type.expiryLabels, expiries).compactMap { label, date in date.map { (label, $0) } }
    }

    var title: String { tag.isEmpty ? type.name : tag }
}
