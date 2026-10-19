import SwiftUI
import SwiftData

@main
struct SafetyRounds: App {
    @State private var entitlements = EntitlementStore()
    @State private var router = AppRouter()
    private let container: ModelContainer

    init() {
        let schema = Schema([Site.self, Asset.self, Inspection.self])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: AppConfig.iCloudSyncEnabled ? .automatic : .none)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetData") {
            let context = container.mainContext
            try? context.delete(model: Inspection.self)
            try? context.delete(model: Asset.self)
            try? context.delete(model: Site.self)
            try? context.save()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(entitlements)
                .environment(router)
                .onOpenURL { router.handle($0) }
        }
        .modelContainer(container)
    }
}
