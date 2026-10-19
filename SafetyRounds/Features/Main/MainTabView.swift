import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            DueView()
                .tabItem { Label("Due", systemImage: "checklist") }
                .tag(AppRouter.Tab.due)
            AssetsView()
                .tabItem { Label("Equipment", systemImage: "flame") }
                .tag(AppRouter.Tab.equipment)
            ReportView()
                .tabItem { Label("Report", systemImage: "doc.text") }
                .tag(AppRouter.Tab.report)
        }
    }
}
