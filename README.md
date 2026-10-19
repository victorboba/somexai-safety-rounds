# Safety Rounds

A monthly inspection log for the safety equipment in a building: fire extinguishers, AEDs, emergency lights, exit signs, eyewash stations, first aid kits, pull stations, sprinkler valves and fire doors. It is for whoever signs the inspection tag in a small facility.

One of a set of niche iPhone apps built from a shared SwiftUI template ([somexai-ios-template](https://github.com/victorboba/somexai-ios-template)). It was never released on the App Store; the code is here for anyone to use. The other apps are collected in [somexai-ios-apps](https://github.com/victorboba/somexai-ios-apps).

## What it does

- **Equipment** by site, each with a tag (such as "EXT-01"), location, details, its own inspection interval (30 days by default, 7 for eyewash) and up to three dated service items (annual service, hydro test, AED pads and battery).
- **Due list**: overdue and never-inspected items first, then items due within 7 days, with the rest collapsed. Tap one to inspect it.
- **Checklists** per equipment type, written from the common monthly visual checks. Everything starts OK; untick what is wrong and add a note and photo. The result is Pass or Needs attention.
- **QR labels**: a label sheet PDF (3 x 4 per Letter page) and a per-item label. The in-app scanner (VisionKit) or the iPhone Camera opens that item's checklist through a `safetyrounds://asset/<id>` link.
- **Report** per site and period: summary, equipment status with next-due dates, items that needed attention with photos, upcoming service dates and the full log. Inspections and equipment export as CSV.
- **Reminders**: a local notification on the morning items are due, and one for overdue, rescheduled on every change.
- Widget with overdue and due-this-week counts, and a How do I use this app guide.

## The boundary

The app records the facility's own inspections. It does not certify compliance, and the report says so. Checklist wording is generic and does not reproduce any standard's text.

## Privacy

Data stays on the device in SwiftData. There is no account, no analytics and no network access; iCloud sync is off (`iCloudSyncEnabled = false`). CSV and PDF files leave the device only when you share them. The QR scanner needs a real camera; the simulator shows a placeholder.

## Build and run

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), and iOS 17 or later.

```bash
xcodegen generate
open SafetyRounds.xcodeproj
```

Pick the `SafetyRounds` scheme and an iPhone simulator, then Run.

Tests:

```bash
xcodebuild -scheme SafetyRounds -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test
```

Paywall: the app has a hard paywall (annual subscription or lifetime purchase). Running from Xcode uses the bundled `Products.storekit` file, so purchases are simulated and free. Debug builds can also skip it with the `-unlock` launch argument or the Debug switch in Settings.

To run on your own device or ship it:

- Set your team in `project.yml` (`DEVELOPMENT_TEAM`).
- Change the `com.example` bundle ID prefix in `project.yml`, both `.entitlements` files and `Products.storekit`.
- Update `supportEmail`, `privacyPolicyURL` and `appStoreID` in `Shared/AppConfig.swift`.

## Notes for developers

- Debug launch arguments: `-unlock`, `-sampleData`, `-resetData`, `-skipOnboarding`, `-mockPrices`.
- `DueCalculator` holds the due-date logic; `AppRouter` handles the `safetyrounds://` deep links.

## Project layout

- `SafetyRounds/App/`: app entry point and `RootView`, the single gate (onboarding, paywall, app).
- `SafetyRounds/Core/`: `DueCalculator`, QR label generation, CSV/PDF export, due-date notifications, StoreKit entitlement store, App Intents, review prompt, sample data.
- `SafetyRounds/Features/`: Due, Equipment, Main, Onboarding, Paywall, Report, Settings.
- `SafetyRounds/Models/`: `Site`, `Asset`, `EquipmentType`, `Inspection`.
- `SafetyRoundsWidget/`: home screen widget reading a snapshot from the App Group.
- `SafetyRoundsTests/`, `SafetyRoundsUITests/`: unit tests and screenshot UI tests.
- `Shared/AppConfig.swift`: everything that changes per app (name, copy, product IDs, links, onboarding, how-to guide).
- App Shortcut: "Start my round in Safety Rounds".

## License

MIT. See [LICENSE](LICENSE).
