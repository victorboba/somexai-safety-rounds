import Foundation
import SwiftData

/// A building or property. Most users have one; property managers have several.
@Model
final class Site {
    var id: UUID = UUID()
    var name: String = ""
    var address: String = ""
    var createdAt: Date = Date()

    init(name: String, address: String = "") {
        self.name = name
        self.address = address
    }
}
