import SwiftUI
import SwiftData

/// Every piece of equipment, grouped by site. Print labels from here.
struct AssetsView: View {
    @Query(sort: \Site.createdAt) private var sites: [Site]
    @Query(sort: \Asset.tag) private var assets: [Asset]
    @Query(sort: \Inspection.date, order: .reverse) private var inspections: [Inspection]

    @State private var showingNew = false
    @State private var showArchived = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    private var sitesByID: [UUID: Site] { Dictionary(uniqueKeysWithValues: sites.map { ($0.id, $0) }) }

    var body: some View {
        NavigationStack {
            Group {
                if assets.isEmpty {
                    ContentUnavailableView {
                        Label("No equipment yet", systemImage: "flame")
                    } description: {
                        Text("Add each extinguisher, AED, exit light and eyewash station with its location.")
                    } actions: {
                        Button("Add Equipment") { showingNew = true }.buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(sites) { site in
                            let siteAssets = assets.filter { $0.siteID == site.id && ($0.isActive || showArchived) }
                            if !siteAssets.isEmpty {
                                Section(site.name) {
                                    ForEach(siteAssets) { asset in
                                        NavigationLink(value: asset.id) {
                                            AssetRow(asset: asset, state: DueCalculator.state(for: asset, last: DueCalculator.lastInspection(for: asset, in: inspections)),
                                                     lastResultPassed: DueCalculator.lastInspection(for: asset, in: inspections)?.passed)
                                            .opacity(asset.isActive ? 1 : 0.5)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .navigationDestination(for: UUID.self) { id in
                        if let asset = assets.first(where: { $0.id == id }) { AssetDetailView(asset: asset) }
                    }
                }
            }
            .navigationTitle("Equipment")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Print QR labels (all active)", systemImage: "printer") { export { try LabelSheetExporter.export(assets: assets.filter(\.isActive), sites: sitesByID) } }
                        Toggle("Show archived", isOn: $showArchived)
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("More")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add equipment")
                }
            }
            .sheet(isPresented: $showingNew) { AssetEditorView(asset: nil) }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
    }

    private func export(_ make: () throws -> URL) {
        do { exportFile = ExportFile(url: try make()) } catch { exportError = error.localizedDescription }
    }
}
