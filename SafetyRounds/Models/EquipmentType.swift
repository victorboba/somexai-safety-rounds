import Foundation

/// The kinds of safety equipment a facility checks on a schedule, each with its own checklist,
/// default interval and dated service items. Checklists follow the common monthly visual-inspection
/// practice (NFPA 10 for extinguishers, NFPA 101 for emergency lighting, ANSI Z358.1 for eyewash),
/// written as plain questions. The app records answers; it does not certify compliance.
enum EquipmentType: String, CaseIterable, Identifiable, Codable {
    case extinguisher, aed, emergencyLight, exitSign, eyewash, firstAidKit, pullStation, sprinklerValve, fireDoor, other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .extinguisher: "Fire extinguisher"
        case .aed: "AED"
        case .emergencyLight: "Emergency light"
        case .exitSign: "Exit sign"
        case .eyewash: "Eyewash / safety shower"
        case .firstAidKit: "First aid kit"
        case .pullStation: "Fire alarm pull station"
        case .sprinklerValve: "Sprinkler control valve"
        case .fireDoor: "Fire door"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .extinguisher: "flame"
        case .aed: "bolt.heart"
        case .emergencyLight: "lightbulb"
        case .exitSign: "figure.walk"
        case .eyewash: "drop"
        case .firstAidKit: "cross.case"
        case .pullStation: "bell"
        case .sprinklerValve: "spigot"
        case .fireDoor: "door.left.hand.closed"
        case .other: "wrench.and.screwdriver"
        }
    }

    /// Suggested tag prefix for new equipment: EXT-01, AED-01…
    var tagPrefix: String {
        switch self {
        case .extinguisher: "EXT"
        case .aed: "AED"
        case .emergencyLight: "EL"
        case .exitSign: "EXIT"
        case .eyewash: "EW"
        case .firstAidKit: "FAK"
        case .pullStation: "PS"
        case .sprinklerValve: "SV"
        case .fireDoor: "FD"
        case .other: "EQ"
        }
    }

    var defaultIntervalDays: Int {
        switch self {
        case .eyewash: 7
        default: 30
        }
    }

    var checklist: [String] {
        switch self {
        case .extinguisher: [
            "In its designated place, visible and unobstructed",
            "Pressure gauge needle in the green",
            "Pull pin and tamper seal intact",
            "No dents, corrosion, leakage or clogged nozzle",
            "Operating instructions on the label face outward",
            "Inspection tag present and annual service current",
            "Mounted securely at the right height",
        ]
        case .aed: [
            "Status indicator shows ready (no alarm or fault)",
            "Electrode pads present, sealed and not expired",
            "Battery not expired",
            "Case, razor, gloves, mask and scissors present",
            "Location sign visible and cabinet unobstructed",
        ]
        case .emergencyLight: [
            "30-second test: lamps light on battery",
            "Charging indicator on when released",
            "Lamps aimed at the egress path, lenses clean",
            "Unit undamaged and mounted securely",
        ]
        case .exitSign: [
            "Sign illuminated and legible from the egress path",
            "30-second battery test passes",
            "Not blocked by decorations, stock or signage",
            "Housing undamaged",
        ]
        case .eyewash: [
            "Activated and flushed until water runs clear",
            "Flow reaches both eyes; shower flow adequate",
            "Dust caps in place, nozzles clean",
            "Path to unit clear, sign visible",
            "Water temperature tepid",
        ]
        case .firstAidKit: [
            "Kit present, accessible and signed",
            "Contents complete against the list inside",
            "Nothing expired or opened",
            "Seal or latch intact",
        ]
        case .pullStation: [
            "Unobstructed and visible",
            "Cover intact and undamaged",
            "Signage present",
        ]
        case .sprinklerValve: [
            "Valve open (fully) and locked or supervised",
            "Gauges read normal pressure",
            "No leaks or physical damage",
            "Access clear, signage present",
        ]
        case .fireDoor: [
            "Door closes and latches fully on its own",
            "No wedges, holds or blocked swing",
            "Seals, hinges and glazing intact",
            "Label present and legible",
        ]
        case .other: [
            "Present and accessible",
            "Undamaged and working",
            "Signage present",
        ]
        }
    }

    /// Dated items worth an expiry warning. Up to three per type; stored on Asset as expiry1…3.
    var expiryLabels: [String] {
        switch self {
        case .extinguisher: ["Annual service due", "6-year maintenance due", "Hydrostatic test due"]
        case .aed: ["Pads expire", "Battery expires"]
        case .emergencyLight, .exitSign: ["Annual 90-minute test due"]
        case .eyewash: ["Annual inspection due"]
        case .firstAidKit: ["Restock check due"]
        case .sprinklerValve: ["Annual test due"]
        case .fireDoor: ["Annual inspection due"]
        case .pullStation, .other: ["Service due"]
        }
    }
}
