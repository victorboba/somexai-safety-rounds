import Foundation

/// The one file to edit when starting a new app from this template.
/// Compiled into both the app and the widget, so keep it free of UIKit/SwiftUI imports.
enum AppConfig {
    // MARK: Identity
    static let appName = "Safety Rounds"
    static let bundleID = "com.example.safety-rounds"
    static let appGroupID = "group.com.example.safety-rounds"
    static let appStoreID = ""
    /// Deep link scheme for QR labels: safetyrounds://asset/<uuid>
    static let urlScheme = "safetyrounds"

    static func assetURL(_ id: UUID) -> URL { URL(string: "\(urlScheme)://asset/\(id.uuidString)")! }

    // MARK: Sync
    static let iCloudSyncEnabled = false

    // MARK: StoreKit
    static let productPrefix = bundleID.replacingOccurrences(of: "-", with: "")
    static let annualProductID = "\(productPrefix).pro.annual"
    static let lifetimeProductID = "\(productPrefix).pro.lifetime"

    // MARK: Links
    static let supportEmail = "support@somexai.com"
    static let privacyPolicyURL = URL(string: "https://somexai.com/privacy/safety-rounds/")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: Copy
    static let entryNoun = "Inspection"
    static let entryNounPlural = "Inspections"
    static let exportFileStem = "safety-rounds"

    static let onboarding: [OnboardingPage] = [
        OnboardingPage(symbol: "flame.circle.fill", title: "Every extinguisher, AED and exit light in one list",
                       body: "Add each piece of safety equipment once, with its location and its own inspection interval."),
        OnboardingPage(symbol: "qrcode.viewfinder", title: "Scan the label, tick the checklist",
                       body: "Print QR labels. On your monthly round, scan and run the NFPA-style checklist in seconds."),
        OnboardingPage(symbol: "doc.text.fill", title: "The record your fire marshal asks for",
                       body: "Overdue items, failures and upcoming service dates in one PDF. Everything stays on your device."),
    ]

    static let paywallSymbol = "checkmark.shield.fill"
    static let paywallHeadline = "Unlock \(appName)"
    static let paywallBenefits = [
        "Unlimited equipment and sites",
        "Checklists for extinguishers, AEDs, exit lights, eyewash and more",
        "QR labels: scan to inspect",
        "Inspection report PDF for the fire marshal",
        "Due-date reminders and widget",
    ]

    static let disclaimer = "\(appName) records your own inspections. It does not replace your local fire code, your insurer's requirements or the tags and professional servicing your equipment needs. When in doubt, ask your fire marshal."

    /// Display prices used only by DEBUG screenshot runs (`-mockPrices`). Keep in sync with StoreKit/Products.storekit.
    static let mockPrices = (annual: "$19.99", lifetime: "$49.99")

    // MARK: Behaviour
    static let reviewAfterSuccesses = 3
    static let dueSoonWindowDays = 7
    static let expiryWarningDays = 30
}

struct OnboardingPage: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
}
