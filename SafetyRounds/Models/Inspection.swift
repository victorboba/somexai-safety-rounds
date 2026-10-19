import Foundation
import SwiftData

/// One completed checklist for one asset. `failedItemsRaw` keeps the checklist lines that were not OK.
@Model
final class Inspection {
    var id: UUID = UUID()
    var assetID: UUID = UUID()
    var date: Date = Date()
    var inspector: String = ""
    var passed: Bool = true
    var failedItemsRaw: String = ""
    var notes: String = ""
    @Attribute(.externalStorage) var photo: Data? = nil
    var createdAt: Date = Date()

    init(asset: Asset, date: Date = .now, inspector: String = "") {
        self.assetID = asset.id
        self.date = date
        self.inspector = inspector
    }

    var failedItems: [String] {
        get { failedItemsRaw.split(separator: "|").map(String.init).filter { !$0.isEmpty } }
        set {
            failedItemsRaw = newValue.joined(separator: "|")
            passed = newValue.isEmpty
        }
    }

    var resultLabel: String { passed ? "Pass" : "Needs attention" }
}
