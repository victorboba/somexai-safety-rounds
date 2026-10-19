import AppIntents
import Foundation

/// "Start my safety round" from Siri or Shortcuts: opens the app on the Due list.
struct StartRoundIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Safety Round"
    static var description = IntentDescription("Opens the list of equipment due for inspection.")
    static var openAppWhenRun = true

    static let pendingKey = "intent.openDue"

    func perform() async throws -> some IntentResult {
        WidgetSnapshot.defaults.set(true, forKey: Self.pendingKey)
        return .result()
    }
}

struct SafetyRoundsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRoundIntent(),
            phrases: ["Start my round in \(.applicationName)", "What's due in \(.applicationName)"],
            shortTitle: "Start Round",
            systemImageName: "checklist"
        )
    }
}
