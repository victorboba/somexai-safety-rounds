import SwiftUI
import SwiftData

/// The round: what is overdue, what is due this week, what is fine. Tap a row to run its checklist.
struct DueView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    @Query(sort: \Site.createdAt) private var sites: [Site]
    @Query(sort: \Asset.tag) private var assets: [Asset]
    @Query(sort: \Inspection.date, order: .reverse) private var inspections: [Inspection]

    @State private var inspecting: Asset?
    @State private var showingScanner = false
    @State private var showingSettings = false
    @State private var showingNewAsset = false
    @State private var siteFilter: UUID?
    @State private var showAllOK = false

    private struct Row: Identifiable {
        let asset: Asset
        let state: DueState
        let last: Inspection?
        var id: UUID { asset.id }
    }

    private var rows: [Row] {
        assets.filter { $0.isActive && (siteFilter == nil || $0.siteID == siteFilter) }.map { asset in
            let last = DueCalculator.lastInspection(for: asset, in: inspections)
            return Row(asset: asset, state: DueCalculator.state(for: asset, last: last), last: last)
        }
    }

    private var overdue: [Row] {
        rows.filter { if case .ok = $0.state { return false }; if case .dueSoon = $0.state { return false }; return true }
            .sorted { lhs, rhs in
                switch (lhs.state, rhs.state) {
                case (.overdue(let a), .overdue(let b)): return a > b
                case (.overdue, _): return true
                default: return lhs.asset.tag < rhs.asset.tag
                }
            }
    }
    private var dueSoon: [Row] { rows.filter { if case .dueSoon = $0.state { return true }; return false }.sorted { dayCount($0.state) < dayCount($1.state) } }
    private var ok: [Row] { rows.filter { if case .ok = $0.state { return true }; return false }.sorted { dayCount($0.state) < dayCount($1.state) } }
    private var sitesByID: [UUID: Site] { Dictionary(uniqueKeysWithValues: sites.map { ($0.id, $0) }) }

    var body: some View {
        NavigationStack {
            Group {
                if assets.isEmpty {
                    ContentUnavailableView {
                        Label("No equipment yet", systemImage: "flame")
                    } description: {
                        Text("Add your extinguishers, AEDs and exit lights, then run your first round.")
                    } actions: {
                        Button("Add Equipment") { showingNewAsset = true }.buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        if !overdue.isEmpty {
                            Section("Overdue or never inspected") { ForEach(overdue) { row(for: $0) } }
                        }
                        if !dueSoon.isEmpty {
                            Section("Due within \(AppConfig.dueSoonWindowDays) days") { ForEach(dueSoon) { row(for: $0) } }
                        }
                        Section {
                            if showAllOK { ForEach(ok) { row(for: $0) } }
                        } header: {
                            HStack {
                                Text("Up to date (\(ok.count))")
                                Spacer()
                                Button(showAllOK ? "Hide" : "Show") { withAnimation { showAllOK.toggle() } }.font(.caption)
                            }
                        }
                        Section {
                            Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Due")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if sites.count > 1 {
                        Menu {
                            Picker("Site", selection: $siteFilter) {
                                Text("All sites").tag(UUID?.none)
                                ForEach(sites) { Text($0.name).tag(Optional($0.id)) }
                            }
                        } label: { Image(systemName: "building.2") }
                        .accessibilityLabel("Filter by site")
                    }
                    Button { showingScanner = true } label: { Image(systemName: "qrcode.viewfinder") }
                        .accessibilityLabel("Scan label")
                }
            }
            .sheet(item: $inspecting) { asset in InspectionSheet(asset: asset) }
            .sheet(isPresented: $showingScanner) {
                ScannerSheet { id in
                    showingScanner = false
                    if let asset = assets.first(where: { $0.id == id }) { inspecting = asset }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingNewAsset) { AssetEditorView(asset: nil) }
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-sampleData"), assets.isEmpty { SampleData.insert(into: context) }
            #endif
        }
        .onChange(of: inspections.count, initial: true) { sync() }
        .onChange(of: assets.count) { sync() }
        .onChange(of: router.pendingAssetID, initial: true) { _, id in
            guard let id, let asset = assets.first(where: { $0.id == id }) else { return }
            router.pendingAssetID = nil
            inspecting = asset
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            if WidgetSnapshot.defaults.bool(forKey: StartRoundIntent.pendingKey) {
                WidgetSnapshot.defaults.removeObject(forKey: StartRoundIntent.pendingKey)
                router.selectedTab = .due
            }
        }
    }

    private func sync() {
        WidgetSync.update(assets: assets, inspections: inspections)
        let a = assets, i = inspections
        Task { await DueReminders.reschedule(assets: a, inspections: i) }
    }

    private func dayCount(_ state: DueState) -> Int {
        switch state {
        case .neverInspected: -10_000
        case .overdue(let d): -d
        case .dueSoon(let d), .ok(let d): d
        }
    }

    private func row(for row: Row) -> some View {
        Button { inspecting = row.asset } label: {
            AssetRow(asset: row.asset, state: row.state, siteName: sites.count > 1 ? sitesByID[row.asset.siteID]?.name : nil, lastResultPassed: row.last?.passed)
        }
        .buttonStyle(.plain)
    }
}

struct AssetRow: View {
    let asset: Asset
    let state: DueState
    var siteName: String?
    var lastResultPassed: Bool?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: asset.type.symbol)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(asset.title).font(.headline)
                    if lastResultPassed == false {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption)
                            .accessibilityLabel("Last inspection needed attention")
                    }
                }
                Text([asset.type.name, asset.location, siteName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(tint.opacity(0.15), in: Capsule())
                .foregroundStyle(tint)
        }
        .contentShape(Rectangle())
    }

    private var label: String {
        switch state {
        case .neverInspected: "Never"
        case .overdue(let d): "\(d)d overdue"
        case .dueSoon(let d): d == 0 ? "Today" : "In \(d)d"
        case .ok(let d): "In \(d)d"
        }
    }

    private var tint: Color {
        switch state {
        case .neverInspected, .overdue: .red
        case .dueSoon: .orange
        case .ok: .secondary
        }
    }
}
